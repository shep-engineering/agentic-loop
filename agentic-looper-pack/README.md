# The Agentic Looper

A small, battle-tested discipline for getting AI coding agents to check their own work
**before** it ships — and an optional append-only ledger that records every time a check
catches something.

It is one loop:

```
PLAN  ->  validate  ->  EXECUTE  ->  validate
```

At each **validate** gate you run two independent checks together:

1. **A fresh, independent reviewer** — a *separate* agent instance that re-derives the answer
   from scratch and tries to find what is wrong. It is NOT given your reasoning or your
   conclusion, so it cannot rubber-stamp them.
2. **A deterministic check that actually runs** — the tests / linters / a real command in the
   real environment, proving the behavior rather than asserting it.

Neither check alone is enough. A reviewer can accept a plausible-but-wrong answer; a test is
blind to a design hole no test targets. Run both, at both gates.

That is the whole idea. Everything in this pack is in service of making that loop *happen
automatically* and *leave a record*.

---

## First: after you unzip

Zipping strips the executable bit off shell scripts on Windows. If you plan to use the hook
(Option B in `MAKE-IT-AUTOMATIC.md`) or the ledger installer, make the scripts executable once:

```bash
chmod +x hooks/loop-reminder.sh install-ledger.sh ledger-templates/pre-commit
```

You need a POSIX shell to run them — on Windows that's **git-bash** (ships with Git for
Windows). If you're only reading `SKILL.md` and adding the standing rule, you can skip this.

---

## Why this exists

Left alone, an agent tends to grade its own homework: it writes code, convinces itself the
code is fine, and moves on. The failure is structural, not a matter of the model being "smart
enough" — the same context that wrote the code is biased toward believing it works.

The fix is **independence**: a second agent that never saw your reasoning, told to be
adversarial and re-derive from scratch. In practice this catches category errors, missing
cases, and false-greens that the original agent simply cannot see about its own work. This
pack is the packaged form of that practice, refined over a lot of real use.

---

## What's in the box

| File | What it is |
|------|-----------|
| `README.md` | This file. |
| `SKILL.md` | **The method.** The full loop procedure, the reusable reviewer prompt, and a worked example. This is the heart of the pack. |
| `MAKE-IT-AUTOMATIC.md` | How to make the loop fire every session (a standing rule) and every turn (a hook), so you don't have to remember it. |
| `hooks/loop-reminder.sh` | The turn-by-turn reminder hook (referenced by MAKE-IT-AUTOMATIC.md, Option B). |
| `install-ledger.sh` | Optional. Installs an **append-only "rejection ledger"** into any git repo, so every time a gate catches something, it's recorded and can't be silently re-tried. |
| `ledger-templates/` | The files the installer lays down: the ledger, its README, and the append-only git hook. |

---

## Prerequisites

- **Claude Code.** This pack is written for [Claude Code](https://claude.com/claude-code) —
  the SKILL is a Claude Code *skill*, and the automation uses Claude Code *hooks* and
  `CLAUDE.md`. The *method* itself is tool-agnostic and works in any agent that can spawn a
  fresh sub-agent (or that you can give a fresh chat), but the drop-in install steps here
  assume Claude Code.
- **A way to spawn a "fresh subagent."** The loop needs an *independent* reviewer. In Claude
  Code that's the Task/Agent tool. If your setup can't spawn sub-agents, the fallback is a
  **brand-new chat/session** with no shared context — paste in only the artifact and the code,
  never your reasoning.
- **For the optional ledger:** `git`, plus `bash` (on Windows, **git-bash**), and `python` or
  `python3` on PATH. The ledger's git hook is a POSIX `sh` script.

---

## Quick start (5 minutes)

1. **Read `SKILL.md`.** It's short and it's the actual method.
2. **Install it as a skill** (so you can invoke it by name):
   - Find your skills folder: `~/.claude/skills/` (Windows: `C:\Users\<you>\.claude\skills\`).
   - Make a folder `agnostic-validation` inside it and copy `SKILL.md` in.
   - Restart Claude Code. Final path: `~/.claude/skills/agnostic-validation/SKILL.md`.
3. **Make it automatic** — follow `MAKE-IT-AUTOMATIC.md` (a standing rule, plus optionally the
   `hooks/loop-reminder.sh` hook).
4. **(Optional) Add the ledger** to a project — see "The ledger" below.

You can stop after step 2 and already benefit: type `/agnostic-validation` and say what you're
validating. Steps 3–4 make it happen without you asking.

---

## A worked example (one full loop)

Say you ask your agent to *"add rate-limiting to the login endpoint."*

1. **PLAN.** The agent writes a short plan: add a token-bucket check in the auth middleware,
   keyed by IP, 5/min.
2. **validate (plan gate).** Spawn a fresh reviewer: *"Here is a plan and the code. Re-derive
   independently where login rate-limiting must apply. Do not trust the plan's list. Find what's
   missing."* It comes back: the plan misses the password-reset endpoint, which is the actual
   brute-force target. **Caught before any code was written.**
3. **EXECUTE.** The agent implements the (now corrected) plan.
4. **validate (diff gate).** A fresh reviewer reads the diff: the limiter keys on a client-set
   `X-Forwarded-For` header, so an attacker rotates it and bypasses the limit. Also runs the
   tests in a real environment — they pass, but the reviewer flags the test only exercised the
   happy path. **Caught before merge.**

Two independent checks, two real defects, neither of which the original agent would have seen
about its own work. That's the loop paying for itself.

---

## The ledger (optional but recommended for serious work)

When a gate *rejects* something, that decision is valuable — it should not vanish, and it should
not be silently re-tried later. The ledger is an **append-only record** of every rejection.

Install it into a git repo (run this **from inside this pack folder** — the installer needs its
sibling `ledger-templates/` directory):

```bash
cd /path/to/agentic-looper-pack
bash install-ledger.sh /path/to/your/repo
```

It will:
- create `validation-log/ledger.md` (the append-only record) and its README;
- install a git `pre-commit` hook that **blocks any edit or deletion of an existing ledger
  entry** — you can only append;
- **compose** with your existing git hooks, or **refuse cleanly** if it can't (it never
  silently disables husky or an existing pre-commit);
- if your repo has a remote, print a NOTE suggesting you commit the ledger via a branch/PR so
  the record gets reviewed. That NOTE is advice, not an error — the install still succeeds.

Uninstall: `bash install-ledger.sh --uninstall /path/to/repo` (keeps the ledger as a record).
Add `--purge` to also delete the ledger content.

**Entry format** (each rejection is one appended block):

```
## <YYYY-MM-DD> — <plan|diff> gate — REJECTED
- **Artifact:** what was under review
- **Verdict:** one line
- **Why:** the defect(s)
- **Context:** repo / branch / commit hash / author / session
```

Putting the commit hash and author in **Context** keeps the tie between a rejected change and
the exact code (and person) it concerned, even for a ledger shared across repos.

---

## Honest limits (so nothing here is oversold)

- **The reminder hook reminds; it does not block.** It re-injects the loop into context every
  turn so the agent doesn't drift, but it can't physically stop an edit that skipped
  validation. Its worst case is being ignored — which is why it's safe to run always.
- **Reviewer independence is a matter of discipline, not a wall.** The reviewer *must* see the
  artifact to review it; what makes it independent is that you don't feed it your conclusion.
  Enforce that in how you prompt it.
- **The ledger's append-only guard is local defense-in-depth, not immutability.** It blocks
  in-place edits to committed entries. It does *not* stop someone with `git commit --amend` /
  rebase / force-push from rewriting history. For a tamper-*evident* record, put the ledger on
  a protected branch or a push-protected remote, or gate it through PR review.
- **The deterministic check must run in the REAL environment.** A test that passes on your host
  but not in the deployed image is a false-green. If a check can't run, it must report BLOCKED
  — and BLOCKED is never a pass.

---

## FAQ / troubleshooting

**The hook doesn't seem to fire.** Confirm the path in `settings.json` is correct, that you
restarted Claude Code, and (Option B) that `hooks/loop-reminder.sh` is executable
(`chmod +x`) and runs under git-bash on Windows.

**`python: command not found`.** The hook and installer try `python3` then `python`. Install
either, or the hook falls back to scanning the raw prompt (slightly less precise, still works).

**The installer printed "has a git remote… commit via a branch/PR."** That's a NOTE, not a
failure. Your files were created; you just decide how to commit them.

**The installer refused.** It refuses rather than clobber when your repo already uses husky, a
classic `.git/hooks/pre-commit`, or a hooksPath pointing elsewhere. Compose the append guard
into your existing setup by hand (the guard is `ledger-templates/pre-commit`).

**Do I need the ledger to use the loop?** No. The loop (SKILL + automation) stands alone. The
ledger is for when you want a durable record of what your gates caught.

---

## License

Use it freely — do whatever you like with it, no attribution required, no warranty. Treat it
as public-domain / MIT-style: it's a small tool shared to be useful.

---

*Provenance: this is a genericized copy of a working setup. Machine-specific paths, names, and
internal integrations have been stripped so it's safe to drop into your own environment.*
