// Self-check for pi-extensions/cedar: run with
//   node --experimental-strip-types test.ts   (cedar-wasm resolvable from here)
// Exercises the bash splitter and the full decide path against a policy set,
// using the same cedar-wasm call the extension makes.
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { bashScopes, projectOf } from "./index.ts";

assert.deepEqual(bashScopes("git status && cargo build"), ["git status", "cargo build"]);
assert.deepEqual(bashScopes("ls | wc -l; echo done"), ["ls", "wc -l", "echo done"]);
assert.deepEqual(bashScopes('echo "a && b" || true'), ['echo "a && b"', "true"]);
assert.deepEqual(bashScopes("x=$(sudo id) && ls"), ["x=$(sudo id) && ls"]); // checked whole
assert.deepEqual(bashScopes("cd /tmp\nsudo ls"), ["cd /tmp", "sudo ls"]);

const cedar = createRequire(import.meta.url)("@cedar-policy/cedar-wasm/nodejs");
const src = [
  '@id("no-sudo")\nforbid(principal, action, resource == Tool::"bash") when { context.scope like "sudo *" };',
  '@id("no-reset")\nforbid(principal, action, resource == Tool::"bash") when { context.scope like "git reset *" } unless { context.project like "ws/postgres/undo*" && context.scope like "git reset --keep*" };',
  `@id("no-ssh")\nforbid(principal, action, resource == Tool::"read") when { context.scope like "${process.env.HOME}/.ssh/*" };`,
  '@id("no-github")\nforbid(principal, action, resource is Tool) when { resource.name like "github.*" };',
].join("\n");
const decide = (tool: string, scope: string, project = "ws/libdb") => {
  const r = cedar.isAuthorized({
    principal: { type: "Agent", id: "pi" },
    action: { type: "Action", id: "invoke" },
    resource: { type: "Tool", id: tool },
    context: { tool, scope, project },
    policies: { staticPolicies: src },
    entities: [{ uid: { type: "Tool", id: tool }, attrs: { name: tool }, parents: [] }],
  });
  assert.equal(r.type, "success", JSON.stringify(r.errors));
  return r.response.decision === "deny" && r.response.diagnostics.reason.length > 0 ? "deny" : "allow";
};
assert.equal(decide("bash", "sudo ls"), "deny");
assert.equal(decide("bash", "ls"), "allow"); // no match -> Pi's default
assert.equal(decide("read", `${process.env.HOME}/.ssh/id_ed25519`), "deny");
assert.equal(decide("read", "/etc/hostname"), "allow");
assert.equal(decide("github.create_issue", "*"), "deny"); // server-wide rule needs the Tool entity
assert.equal(decide("git.git_log", "*"), "allow");
// per-project carve-out: only in its project, and only the narrow form
assert.equal(decide("bash", "git reset --keep HEAD~1", "ws/postgres/undo"), "allow");
assert.equal(decide("bash", "git reset --keep HEAD~1", "ws/libdb"), "deny");
assert.equal(decide("bash", "git reset --hard", "ws/postgres/undo"), "deny");
assert.equal(projectOf(`${process.env.HOME}/ws/postgres/undo`), "ws/postgres/undo");
assert.equal(projectOf(`${process.env.HOME}`), "~");
assert.equal(projectOf("/scratch/x"), "/scratch/x");
console.log("pi-cedar self-check: ok");
