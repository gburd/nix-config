# Prose Mechanics

Conventions for anything that ships under my name and outlives the moment:
commit messages, code comments, documentation, e-mail, and design notes.
These are style rules, not judgment calls. Apply them without being asked.

## Sentences and punctuation

- Two spaces after every sentence-ending period. Exactly two, every time.
- No dashes as asides or joiners: no em dash, no en dash, no double hyphen
  (`--`). Use parentheses, a comma, a colon, or start a new sentence. This
  holds in prose, comments, and commit messages alike.
- Serial (Oxford) comma, always: "a, b, and c", never "a, b and c".
- Prefer the active voice and avoid the verb "to be". Name the actor and
  give it a real verb: "the hook blocks the push", not "the push is blocked"
  or "the push will be blocked by the hook". "The file is large" becomes
  "the file holds 40k lines". Some uses of "to be" are unavoidable (a genuine
  state of being, a passive where the actor is unknown or irrelevant); the
  rule is to reach for an actor and an active verb first, and keep "is/are/
  was/were/be/being/been" only when nothing clearer fits.
- "e.g." and "i.e." always take a following comma.
- Contractions are normal. The register is plain idiomatic American
  English, not formal written English and not chat shorthand.
- Complete sentences with a capital and a period, including in comments.
  The exception is telegraphic fragments where the form is conventional:
  trailing comments on struct members, short guards, and test
  description strings.

## Naming things in prose

- Functions get trailing parens: `foo()`.
- Configuration settings, command-line options, and file names are bare:
  unquoted and unmarked.
- Emphasis is `_underscores_`. No emoticons. Humor stays deadpan and rare.

## Commit messages (generic)

The project-specific rules in the domain steering (e.g. PostgreSQL) take
precedence where they differ. Absent those:

- A terse imperative subject line, then plain prose paragraphs. No
  bullets and no boilerplate in the body unless the change genuinely
  enumerates sub-changes.
- The message must stand alone: enough background to understand the
  problem (for a small fix, often none), then the change, in that order.
- Carry what the diff cannot: why the change is needed, the caveats and
  how they are handled, the alternatives considered and why they lost,
  and the work deliberately left for later.
- Describe intent only as far as you can point to it. A re-derived
  explanation may be subtly wrong, and the record is permanent.
- Scale the message to the change. A small or obvious change needs a
  line or two. Judgment over formula.
- "I" for judgment calls, "we" for project decisions.

## Register in discussion

- Separate verified from inferred explicitly: "If I set X, it no longer
  hangs." versus "I suspect ...", "IIUC ...", "My guess is ...".
- Disagreement is plain declarative aimed at the argument, not the
  person: "I don't think we want to ...", "I'm not seeing why we
  wouldn't just ...".
- Concede quickly and completely when shown wrong: "Fair point.",
  "You're right, ...", "I retract my objection."
- Label the quality of your own work honestly. A fragile
  proof-of-concept is described as one.
