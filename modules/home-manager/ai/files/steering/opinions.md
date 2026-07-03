# Opinions

Subjective preferences and taste — how the maintainer likes generated output
(prose, commits, PRs, docs, naming) to read. These are not correctness rules
(those live in must-rules / coding-standards / workflow); they are personal
style. When a preference here conflicts with clarity or correctness, clarity
wins — but absent a reason, follow these.

## Punctuation & prose

- **Never use the em-dash (—) in generated prose.** Use a plain hyphen with
  spaces ( - ), a comma, or a rewrite. Models default to em-dashes and it reads
  as robotic AI output. This applies to PR descriptions, commit bodies, docs,
  comments, and chat prose alike.
- **Plain, factual language.** In PR/commit descriptions and docs, describe what
  the code does now — not discarded approaches or prior iterations. Avoid the
  inflated register: critical, crucial, essential, significant, comprehensive,
  robust, elegant, seamless, powerful, cutting-edge.
- **No filler validation.** Don't open with "Great question", "You're absolutely
  right", "Fascinating" or similar. Get to the answer.

## Formatting

- Prefer terse bullet points over walls of prose for status/plans.
- Fenced code blocks with a language tag for any code or command.
- Don't emit trailing "Let me know if you need anything else" boilerplate.
