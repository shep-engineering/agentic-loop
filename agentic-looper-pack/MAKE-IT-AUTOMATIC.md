# Make the agnostic validator run every time

Installing `SKILL.md` only makes the skill *available*. It does not make it *fire*. A skill
runs when someone types `/agnostic-validation` or when Claude decides to reach for it. To make
it automatic, you must put the rule somewhere the tool loads or runs on every turn.

There are two layers. Layer 1 is enough for most people. Add Layer 2 if you want it hardwired.

---

## Layer 1 — Standing rule in CLAUDE.md (do this first)

Claude Code reads `CLAUDE.md` into context at the start of every session. A rule placed here
is seen every time, in every session.

1. Open (or create) one of these files:
   - Per project: `CLAUDE.md` in the root of the project you are working in.
   - For all projects: `~/.claude/CLAUDE.md` (Windows: `C:\Users\<you>\.claude\CLAUDE.md`).
2. Paste this block into it and save:

```
## Non-negotiable: agnostic-validate every substantive change

All substantive work follows this loop: PLAN -> agnostic-validate -> EXECUTE -> agnostic-validate.
Invoke the /agnostic-validation skill at BOTH gates. Do not skip a gate.
Do not wait for me to remind you. Run the validation yourself, then report the result.
Scale the effort to the risk: a one-line fix earns one reviewer; a risky change earns a
reviewer plus a real test run.

Reviewer independence is enforced by prose (re-derive, do not inherit the conclusion), not a
file boundary — the reviewer must see the artifact. The structural boundary belongs on the
deterministic leg: freeze the oracle (fixtures, golden data) outside the author's edit reach,
and at the diff gate flag any oracle file that appears in the same diff as the code.
Log every gate rejection durably where the reviewed author cannot quietly erase it; a bare
local commit does not qualify.
```

This is loaded every session. It is strong, but it is still advice — under a heavy task the
model can drift. If that is not good enough, add Layer 2.

---

## Layer 2 — A hook that re-injects the rule on every prompt (hardwired)

A `UserPromptSubmit` hook runs on every message you send. Its output is added to the model's
context that turn. This re-states the rule every single turn, so the model cannot drift away
from it the way it can with a rule seen only once at session start.

Add this to your Claude Code settings file:
- Per project: `.claude/settings.json` in the project root.
- For all projects: `~/.claude/settings.json` (Windows: `C:\Users\<you>\.claude\settings.json`).

If the file already has a `"hooks"` key, **merge** this into it rather than overwriting — a
`settings.json` often holds other hooks you do not want to lose.

**Option A — the simplest possible reminder (one line, always fires):**

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo REMINDER: This work follows PLAN -> validate -> EXECUTE -> validate. Invoke /agnostic-validation at both gates without being asked."
          }
        ]
      }
    ]
  }
}
```

**Option B — the bundled script (smarter; only fires on turns that intend to change something):**

This pack includes `hooks/loop-reminder.sh`. It stays silent on read-only / conversational
turns and injects the loop reminder only when the prompt looks like real work. Copy it somewhere
stable (e.g. `~/.claude/hooks/loop-reminder.sh`), make it executable, and point the hook at it:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.claude/hooks/loop-reminder.sh\""
          }
        ]
      }
    ]
  }
}
```

On Windows, run the script through git-bash and make sure `python` or `python3` is on PATH
(the script degrades gracefully if neither is present). Make it executable first:
`chmod +x ~/.claude/hooks/loop-reminder.sh`.

Restart Claude Code after you save it. From then on, every prompt carries the reminder.

Note on the honest limit: this hook *reminds* every turn — it does not physically block an edit
that skipped validation. That is enough in practice, because the reminder is present at the
moment the model plans each action. A true block (refuse to edit until validation ran) is a
larger PreToolUse hook and is usually not worth the complexity.

---

## Which to use

- Want it simple and solid: Layer 1 only.
- Want it hardwired so it survives long, heavy sessions: Layer 1 AND Layer 2.
