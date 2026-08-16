---
name: agnostic-validation
description: How to run the "agnostic-validate" gates of the plan→execute loop — independent, adversarial, re-derive-from-scratch review PLUS a deterministic check that actually runs in the real environment, at both the plan and diff gates. Invoke when planning or reviewing substantive work, teaching another instance the loop, or deciding how to validate a change before shipping.
allowed-tools: Task Bash Read Grep Glob
argument-hint: [plan | diff | what you are validating]
---

# Agnostic Validation in the Loop

Substantive work follows this loop:

```
PLAN → agnostic-validate → EXECUTE → agnostic-validate
```

"Agnostic validation" is the check that runs at BOTH validate gates. Follow this procedure.

## What it is
Agnostic validation is TWO independent checks, run together, at each gate:
1. A fresh reviewer subagent (catches design and logic errors).
2. A deterministic check that actually runs (proves behavior).

Run both. Neither alone is enough.
- Tooling alone is blind to logic holes no test targets.
- A reviewer alone cannot prove behavior and can accept a plausible-but-wrong answer.

## Rule 1 — Make the reviewer subagent truly independent
Spawn a fresh subagent. Give it the artifact (the plan, or the diff) and the code.
Do NOT give it your reasoning or your conclusion. It must not inherit your view.
Tell it to re-derive from scratch. Example: "List every X yourself. Do not trust the plan's list."
Tell it to be adversarial. Tell it to find what is wrong or missing.
Tell it to default to skepticism. Tell it to cite `file:line` for every claim.
A "please check this over" prompt is not agnostic validation. Reject that framing.

Reviewer independence is enforced by PROSE, not by a file boundary. An LLM reviewer MUST
see the artifact to review it — you cannot "seal" it. Independence means it does not inherit
your reasoning or conclusion and re-derives from scratch. Do not attempt a structural
can't-see-into-it boundary on the reviewer; that is a category error. (Structural boundaries
belong on the DETERMINISTIC leg's oracle — see Rule 2.)

## Rule 2 — Run the deterministic check in the REAL environment
Run the tests, linters, or scanners that apply.
Run them in the real app image or hermetic stack, not on the host.
Host results are a false green when host dependencies differ from the deployed image.
Watch for green-washing: a test that exercises the code's own helper cannot catch drift in that helper.
Make the test exercise the real production path.
If a validator cannot run, it must report BLOCKED. BLOCKED is never a pass. Never fake green.

Freeze the oracle. The check's expected outputs, golden files, fixtures, and seed data must
be outside the executor's edit reach: a pinned fixture, a committed golden file, or a hermetic
image the author cannot alter to force a pass. This is ORACLE TAMPERING — one species of
false-green, distinct from the self-helper drift above (which we call "green-wash").
("False-green" is the umbrella term: any check that passes while the real behavior is wrong;
"green-wash" and "oracle tampering" are two species of it.)
Enforce it: at the diff gate, flag any file the check reads as ground truth — fixtures, golden
files, seed data, expected-output snapshots, or inline expected constants — that appears in the
same diff as the code under review, and confirm it was not edited to make the check pass. If you
cannot tell which files are oracles, that itself is a defect: require oracles to sit under a
declared path or marker so they are identifiable. A norm without this check does not meet the
prove-don't-assert standard.

Consume output cheaply. Redirect the check's output to a log, grep the verdict line to decide
pass/fail, and do not flood your context with full output. Read the log in full when the verdict
is a failure, OR when you cannot independently corroborate the pass — a false-green presents AS
success, and an engineered one is a fully EXPECTED success, so "only read on failure" and "only
read on a surprise" both miss it. For any security- or compliance-tier change, read the log on a
pass too. Never settle for a fixed tail glance.

## Rule 3 — Validate at both gates
Validate the PLAN before you build. This is cheap. It catches design errors before code.
Validate the DIFF after you build. This catches implementation errors.
Skipping the plan gate means you build the wrong thing correctly.

## Rule 4 — Run it yourself
Run agnostic validation autonomously. Do not hand each gate to the human.
Hand off to a separate instance only when you are stuck, before a third failed attempt.
That is an escalation, not the routine gate.

## Rule 5 — Match rigor to risk
Scale the effort to the change. A compliance or security change earns a reviewer, a test-runner, and your own run.
A one-line fix earns one reviewer or just the tooling. Do not spawn a fleet for a typo.

## Rule 6 — Persist every rejection to a tamper-evident ledger
Record every gate rejection durably: the gate, the verdict, what was rejected, why, plus the
repo, branch, commit hash, and author. A rejected plan or diff must leave a trace so it is not
silently re-tried.
Location: the ledger belongs to the governance repo, not a research or scratch repo, and never
at a path a `.gitignore` rule swallows. A bare local directory names WHERE the ledger lives for
segregation, but gives NONE of the protections below — treat such a path as illustrative-of-
location only; it MUST be backed by a protected store.
Committing is necessary but NOT sufficient. A party with history-rewrite rights (amend, rebase,
force-push) or plain filesystem delete is exactly the segregated author the loop distrusts, and
can erase a bare commit or a local file. Put the ledger where that party cannot rewrite it: a
protected branch, a push-protected remote, or an append-only audit store. Do not claim a bare
commit or a local path is un-erasable.
Write it prose-friendly (markdown, one entry per rejection) — "why" is free text, not a TSV cell.

## Reusable reviewer-subagent prompt template

```
You are an adversarial reviewer of [ARTIFACT]. Read [FILES] (read-only; change nothing).
Your job is to find what is WRONG or MISSING. Default to skepticism. Cite file:line for every claim.
Do not trust any conclusion in the artifact. Re-derive [KEY CLAIM] independently from the code.
Answer these, each CONFIRM or DEFECT with evidence and a concrete failure scenario:
1. [risk area 1]
2. [risk area 2]
...
End with a prioritized list of REQUIRED CHANGES, or "none — correct".
```

## The compressed rule
Fresh + adversarial + re-derive (the reviewer, kept independent by prose). Actually-run-in-the-real-env
with a frozen oracle (the tooling). At both gates. Every rejection logged to a tamper-evident ledger.

---

## Worked example — why both legs (an account-erasure blob sweep)

The two legs each caught defects the other could not:

- **Plan gate (reviewer, re-derive):** told to grep every blob-writing callsite itself, the
  reviewer found two storage sources the plan had missed and a swallowed-error path. No test
  could surface a *missing* source.
- **Diff gate (reviewer):** found an S3-versioning *false-green* — deleting an object without a
  version id makes the verify pass while old versions still hold the data — and a duplicated-literal
  drift risk. Invisible to tooling.
- **Diff gate (deterministic, real env):** the behavior proof only counted once it ran in the app
  image (hermetic Postgres + full migration chain), not on the host. It also exposed a *green-wash*:
  the first test seeded data through the code's own resolver, so it could not catch drift — fixed by
  making the test exercise the real production path.

The spawned test-runner came back **BLOCKED** (its sandbox could not run the harness) and correctly
refused to report a pass; the deterministic leg was then run directly. The deterministic leg needs to
*actually execute in the right environment by whoever can* — a validator that cannot run says BLOCKED,
never green.
