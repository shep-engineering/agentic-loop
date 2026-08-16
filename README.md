# agentic-loop

Working directory for the **agentic loop** — the `plan → validate → execute → validate`
discipline, its tooling, and the research that informed it.

## What's here

| Path | What it is |
|------|-----------|
| `agentic-looper-pack/` | The **shareable** version of the loop — a self-contained kit (method + automation + optional ledger) genericized for anyone. See its own `README.md`. |

The loop pattern here is informed by Andrej Karpathy's [autoresearch](https://github.com/karpathy/autoresearch)
(public, MIT) — a human edits a strategy doc, an agent iterates code against one metric, and keeps
or reverts per result.

## What the loop actually is

Substantive work follows one loop:

```
PLAN → validate → EXECUTE → validate
```

At each **validate** gate, two independent checks run together:
1. A **fresh, independent reviewer** subagent that re-derives from scratch and hunts for what's
   wrong — never given the author's reasoning or conclusion.
2. A **deterministic check** that actually runs in the real environment and proves behavior.

Neither alone is enough. This is the answer to "how do you keep an AI agent from grading its
own homework": a second agent that never saw the first one's reasoning.

## Where the loop should live on your machine (not in this folder)

Install the loop **globally** so it applies to every project and every agent instance:

- **Method (skill):** `~/.claude/skills/agnostic-validation/SKILL.md` — invoke with `/agnostic-validation`.
- **Automation (hook):** `~/.claude/hooks/loop-reminder.sh`, wired into `~/.claude/settings.json`.
  It re-injects the loop on work-intent turns and stays silent on read-only turns.
- **Optional ledger:** add the append-only rejection ledger to any repo with the installer in
  `agentic-looper-pack/` (`install-ledger.sh`); the ledger lives in that repo's `validation-log/`.

So there is **no "launch method"** — an instance doesn't run *under* the loop, it *follows* it.
A new instance picks it up automatically; a running one just needs a one-line nudge.

## The share pack

`agentic-looper-pack/` is a self-contained, genericized copy of the loop — the method, the
automation, and the optional ledger — ready to drop into anyone's setup. It has its own README.

## Provenance

The loop's design borrows three disciplines from autoresearch: a structural evaluator boundary,
a tamper-evident rejection ledger, and context/verdict hygiene. Each was developed by running it
through the loop itself, with the decision history recorded in
[open-brain](https://github.com/shep-engineering/open-brain) (a persistent agent memory / MCP server).
