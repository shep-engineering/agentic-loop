# validation-log

Append-only ledger of agnostic-validation gate REJECTIONS (SKILL Rule 6).

## What goes here
One entry per gate rejection: date, gate (plan|diff), verdict, what was rejected, why,
and commit/author context. A rejection here must never be silently re-tried, and — once
pushed to a protected remote or merged via review — must not be quietly erased.

## Rules
- APPEND only. Never edit or delete an existing entry. A correction is a NEW entry that
  references the one it supersedes.
- Entries are prose (markdown); "why" is free text.
- Tamper-evidence comes from the push-protected remote and/or branch-PR review, NOT the
  local commit alone. A local commit is erasable by the author it is meant to constrain.
- The pre-commit guard enforces append-only locally for committers with git-bash/POSIX sh.

## Entry format
```
## <YYYY-MM-DD> — <plan|diff> gate — REJECTED
- **Artifact:** <what was under review>
- **Verdict:** <one-line>
- **Why:** <the defect(s), free text>
- **Context:** <repo / branch / commit hash / author / session, if any>
```
