//! cedar-store: a minimal Cedar 4 policy store speaking cedar-agent's API.
//!
//! Why not permitio/cedar-agent: it bundles cedar-policy 2.4 (rejects Cedar
//! 3+ syntax such as `resource is Tool`, which maki's export-cedar emits) and
//! its token gate covers reads too, while maki's client sends no token.
//!
//! API (cedar-agent compatible where maki and the pi extension read):
//!   GET  /v1/policies        -> [{"id","content"}]          (open)
//!   GET  /v1/schema          -> schema JSON or 404           (open)
//!   POST /v1/is_authorized   -> {"decision","diagnostics"}   (open)
//!   PUT  /v1/policies        <- [{"id","content"}]           (Bearer token)
//!   PUT  /v1/policies/text   <- Cedar policy-set source       (Bearer token)
//!   GET  /health             -> {"policies": n}
//! Reads are open on purpose: the listener is tailnet-only and a policy set
//! is not a secret; writes need `Authorization: Bearer <token>` so no agent
//! can widen its own permissions. Every accepted write is validated (and,
//! with a schema, type-checked) before it replaces the set, then persisted
//! atomically to the state file so a restart serves the same policies.
//!
//! env: CEDAR_STORE_ADDR (default 127.0.0.1:8180), CEDAR_STORE_STATE
//! (policy file, default ./policies.json), CEDAR_STORE_SCHEMA (optional
//! .cedarschema), CEDAR_STORE_TOKEN_FILE (write token; unset = read-only).

use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::str::FromStr;
use std::io::Read;
use std::sync::RwLock;

use cedar_policy::{
    Authorizer, Context, Decision, Entities, EntityUid, Policy, PolicyId, PolicySet, Request,
    Schema, ValidationMode, Validator,
};
use serde::{Deserialize, Serialize};
use tiny_http::{Header, Method, Response, Server};

#[derive(Clone, Serialize, Deserialize)]
struct StoredPolicy {
    id: String,
    content: String,
}

struct State {
    policies: Vec<StoredPolicy>,
    set: PolicySet,
}

struct App {
    state: RwLock<State>,
    state_path: PathBuf,
    schema: Option<Schema>,
    schema_json: Option<serde_json::Value>,
    token: Option<String>,
}

/// Parse + (optionally) validate policies. Ids must be unique; each content
/// must hold exactly one policy so ids stay stable across round trips.
fn build_set(policies: &[StoredPolicy], schema: Option<&Schema>) -> Result<PolicySet, String> {
    let mut set = PolicySet::new();
    for p in policies {
        if p.id.is_empty() {
            return Err("policy with empty id".into());
        }
        let pid = PolicyId::from_str(&p.id).map_err(|e| format!("bad id {:?}: {e}", p.id))?;
        let pol = Policy::parse(Some(pid), &p.content).map_err(|e| format!("policy {:?}: {e}", p.id))?;
        set.add(pol).map_err(|e| format!("policy {:?}: {e}", p.id))?;
    }
    if let Some(schema) = schema {
        let res = Validator::new(schema.clone()).validate(&set, ValidationMode::Strict);
        if !res.validation_passed() {
            let errs: Vec<String> = res.validation_errors().map(|e| e.to_string()).collect();
            return Err(format!("schema validation failed: {}", errs.join("; ")));
        }
    }
    Ok(set)
}

/// Split Cedar source into id'd policies. An `@id("x")` annotation names a
/// policy; unnamed ones get `policy<N>` (Cedar's own default naming).
fn split_source(src: &str) -> Result<Vec<StoredPolicy>, String> {
    let set = PolicySet::from_str(src).map_err(|e| e.to_string())?;
    let mut out: BTreeMap<String, StoredPolicy> = BTreeMap::new();
    for p in set.policies() {
        let id = p.annotation("id").map(str::to_string).unwrap_or_else(|| p.id().to_string());
        let content = p.to_string();
        if out.insert(id.clone(), StoredPolicy { id: id.clone(), content }).is_some() {
            return Err(format!("duplicate policy id {id:?}"));
        }
    }
    Ok(out.into_values().collect())
}

fn persist(path: &Path, policies: &[StoredPolicy]) -> Result<(), String> {
    let tmp = path.with_extension("json.tmp");
    let body = serde_json::to_vec_pretty(policies).map_err(|e| e.to_string())?;
    fs::write(&tmp, body).map_err(|e| format!("write {}: {e}", tmp.display()))?;
    fs::rename(&tmp, path).map_err(|e| format!("rename {}: {e}", path.display()))
}

fn json(code: u16, v: &serde_json::Value) -> Response<std::io::Cursor<Vec<u8>>> {
    Response::from_data(serde_json::to_vec(v).unwrap_or_default())
        .with_status_code(code)
        .with_header(Header::from_bytes("Content-Type", "application/json").unwrap())
}

fn err(code: u16, msg: impl Into<String>) -> Response<std::io::Cursor<Vec<u8>>> {
    json(code, &serde_json::json!({ "error": msg.into() }))
}

#[derive(Deserialize)]
struct AuthzQuery {
    principal: String,
    action: String,
    resource: String,
    #[serde(default)]
    context: serde_json::Value,
}

impl App {
    fn authorized_write(&self, req: &tiny_http::Request) -> bool {
        let Some(token) = &self.token else { return false };
        req.headers().iter().any(|h| {
            h.field.equiv("Authorization")
                && h.value.as_str().strip_prefix("Bearer ").is_some_and(|t| t == token)
        })
    }

    fn replace(&self, policies: Vec<StoredPolicy>) -> Result<usize, String> {
        let set = build_set(&policies, self.schema.as_ref())?;
        persist(&self.state_path, &policies)?;
        let n = policies.len();
        *self.state.write().unwrap() = State { policies, set };
        Ok(n)
    }

    fn is_authorized(&self, q: AuthzQuery) -> Result<serde_json::Value, String> {
        let p = EntityUid::from_str(&q.principal).map_err(|e| format!("principal: {e}"))?;
        let a = EntityUid::from_str(&q.action).map_err(|e| format!("action: {e}"))?;
        let r = EntityUid::from_str(&q.resource).map_err(|e| format!("resource: {e}"))?;
        let ctx = match q.context {
            serde_json::Value::Null => Context::empty(),
            v => Context::from_json_value(v, None).map_err(|e| format!("context: {e}"))?,
        };
        let request = Request::new(p, a, r, ctx, None).map_err(|e| e.to_string())?;
        let st = self.state.read().unwrap();
        let resp = Authorizer::new().is_authorized(&request, &st.set, &Entities::empty());
        let reasons: Vec<String> = resp.diagnostics().reason().map(|id| id.to_string()).collect();
        let errors: Vec<String> = resp.diagnostics().errors().map(|e| e.to_string()).collect();
        // Cedar is two-valued; "Deny" with no reason means no policy matched.
        // `matched` lets a per-call client defer instead of hard-denying.
        Ok(serde_json::json!({
            "decision": if resp.decision() == Decision::Allow { "Allow" } else { "Deny" },
            "matched": !reasons.is_empty(),
            "diagnostics": { "reason": reasons, "errors": errors },
        }))
    }

    fn handle(&self, mut req: tiny_http::Request) {
        let url = req.url().split('?').next().unwrap_or("").to_string();
        let mut body = String::new();
        let _ = req.as_reader().read_to_string(&mut body);
        let resp = match (req.method(), url.as_str()) {
            (Method::Get, "/health") => {
                json(200, &serde_json::json!({ "policies": self.state.read().unwrap().policies.len() }))
            }
            (Method::Get, "/v1/policies") => {
                json(200, &serde_json::to_value(&self.state.read().unwrap().policies).unwrap())
            }
            (Method::Get, "/v1/schema") => match &self.schema_json {
                Some(v) => json(200, v),
                None => err(404, "no schema"),
            },
            (Method::Post, "/v1/is_authorized") => match serde_json::from_str::<AuthzQuery>(&body)
                .map_err(|e| e.to_string())
                .and_then(|q| self.is_authorized(q))
            {
                Ok(v) => json(200, &v),
                Err(e) => err(400, e),
            },
            (Method::Put, "/v1/policies") | (Method::Put, "/v1/policies/text") => {
                if !self.authorized_write(&req) {
                    err(401, "write requires Authorization: Bearer <token>")
                } else {
                    let parsed = if url.ends_with("/text") {
                        split_source(&body)
                    } else {
                        serde_json::from_str::<Vec<StoredPolicy>>(&body).map_err(|e| e.to_string())
                    };
                    match parsed.and_then(|ps| self.replace(ps)) {
                        Ok(n) => json(200, &serde_json::json!({ "policies": n })),
                        Err(e) => err(400, e),
                    }
                }
            }
            _ => err(404, "not found"),
        };
        let _ = req.respond(resp);
    }
}

fn main() {
    let addr = std::env::var("CEDAR_STORE_ADDR").unwrap_or_else(|_| "127.0.0.1:8180".into());
    let state_path = PathBuf::from(std::env::var("CEDAR_STORE_STATE").unwrap_or_else(|_| "policies.json".into()));
    let (schema, schema_json) = match std::env::var("CEDAR_STORE_SCHEMA") {
        Ok(p) => {
            let src = fs::read_to_string(&p).unwrap_or_else(|e| panic!("read schema {p}: {e}"));
            let (s, _warnings) = Schema::from_cedarschema_str(&src).unwrap_or_else(|e| panic!("schema {p}: {e}"));
            // cedar-agent serves JSON schema; convert the human form once.
            let js = cedar_policy::SchemaFragment::from_cedarschema_str(&src)
                .ok()
                .and_then(|(f, _)| f.to_json_value().ok());
            (Some(s), js)
        }
        Err(_) => (None, None),
    };
    let token = std::env::var("CEDAR_STORE_TOKEN_FILE")
        .ok()
        .map(|p| fs::read_to_string(&p).unwrap_or_else(|e| panic!("read token {p}: {e}")).trim().to_string())
        .filter(|t| !t.is_empty());
    let policies: Vec<StoredPolicy> = match fs::read(&state_path) {
        Ok(b) => serde_json::from_slice(&b).unwrap_or_else(|e| panic!("state {}: {e}", state_path.display())),
        Err(_) => Vec::new(),
    };
    let set = build_set(&policies, schema.as_ref()).unwrap_or_else(|e| panic!("stored policies invalid: {e}"));
    let app = App {
        state: RwLock::new(State { policies, set }),
        state_path,
        schema,
        schema_json,
        token,
    };
    let server = Server::http(&addr).unwrap_or_else(|e| panic!("bind {addr}: {e}"));
    eprintln!(
        "cedar-store: listening on {addr}, {} policies, schema={}, writes={}",
        app.state.read().unwrap().policies.len(),
        app.schema.is_some(),
        if app.token.is_some() { "token" } else { "disabled" }
    );
    for req in server.incoming_requests() {
        app.handle(req);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const SCHEMA: &str = r#"
entity Agent;
entity Tool = { "name": String };
action invoke appliesTo { principal: [Agent], resource: [Tool], context: { "scope": String, "tool": String } };
"#;

    fn app(policies: &[(&str, &str)]) -> App {
        let ps: Vec<StoredPolicy> = policies
            .iter()
            .map(|(i, c)| StoredPolicy { id: i.to_string(), content: c.to_string() })
            .collect();
        let (schema, _) = Schema::from_cedarschema_str(SCHEMA).unwrap();
        let set = build_set(&ps, Some(&schema)).unwrap();
        App {
            state: RwLock::new(State { policies: ps, set }),
            state_path: std::env::temp_dir().join(format!("cedar-store-test-{}.json", std::process::id())),
            schema: Some(schema),
            schema_json: None,
            token: Some("t".into()),
        }
    }

    fn ask(a: &App, tool: &str, scope: &str) -> (String, bool) {
        let v = a
            .is_authorized(AuthzQuery {
                principal: r#"Agent::"maki""#.into(),
                action: r#"Action::"invoke""#.into(),
                resource: format!(r#"Tool::"{tool}""#),
                context: serde_json::json!({ "tool": tool, "scope": scope }),
            })
            .unwrap();
        (v["decision"].as_str().unwrap().to_string(), v["matched"].as_bool().unwrap())
    }

    #[test]
    fn permit_forbid_and_no_match() {
        let a = app(&[
            ("git", r#"permit(principal, action, resource == Tool::"bash") when { context.scope like "git *" };"#),
            ("sudo", r#"forbid(principal, action, resource == Tool::"bash") when { context.scope like "sudo *" };"#),
        ]);
        assert_eq!(ask(&a, "bash", "git status"), ("Allow".into(), true));
        assert_eq!(ask(&a, "bash", "sudo ls"), ("Deny".into(), true));
        assert_eq!(ask(&a, "bash", "ls"), ("Deny".into(), false)); // no match: defer
    }

    #[test]
    fn cedar4_syntax_accepted() {
        // `resource is Tool` is Cedar 3+; cedar-agent 0.2.2 rejects it.
        app(&[("all", r#"forbid(principal, action, resource is Tool) when { context.scope like "rm -rf *" };"#)]);
    }

    #[test]
    fn schema_rejects_bad_attribute() {
        let (schema, _) = Schema::from_cedarschema_str(SCHEMA).unwrap();
        let bad = vec![StoredPolicy {
            id: "x".into(),
            content: r#"permit(principal, action, resource) when { context.nope == "a" };"#.into(),
        }];
        assert!(build_set(&bad, Some(&schema)).is_err());
    }

    #[test]
    fn split_source_uses_id_annotations() {
        let ps = split_source(
            "@id(\"a\")\npermit(principal, action, resource);\n@id(\"b\")\nforbid(principal, action, resource);",
        )
        .unwrap();
        assert_eq!(ps.iter().map(|p| p.id.as_str()).collect::<Vec<_>>(), vec!["a", "b"]);
    }

    #[test]
    fn replace_persists_and_round_trips() {
        let a = app(&[]);
        let n = a
            .replace(vec![StoredPolicy {
                id: "p".into(),
                content: r#"permit(principal, action, resource == Tool::"bash") when { context.scope like "make *" };"#.into(),
            }])
            .unwrap();
        assert_eq!(n, 1);
        let back: Vec<StoredPolicy> = serde_json::from_slice(&fs::read(&a.state_path).unwrap()).unwrap();
        assert_eq!(back[0].id, "p");
        assert_eq!(ask(&a, "bash", "make all"), ("Allow".into(), true));
        let _ = fs::remove_file(&a.state_path);
    }
}
