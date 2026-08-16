#!/usr/bin/env bash
# loop-reminder.sh — a Claude Code UserPromptSubmit hook.
#
# Re-injects the "plan -> validate -> execute -> validate" discipline on turns that intend to
# change something, so the loop never falls out of context on a long session. UserPromptSubmit
# stdout is added to the live prompt every turn, so the reminder cannot be summarised away.
#
# It is a REMINDER, not a block: its worst case is being ignored, so it carries no false-block
# or hook-fatigue risk. It stays silent on read-only / analysis / conversational turns.
#
# Install: see MAKE-IT-AUTOMATIC.md (Layer 2). On Windows this needs git-bash (POSIX sh) and
# python or python3 on PATH.

PYBIN="$(command -v python3 || command -v python || true)"

INPUT=$(cat)
if [ -n "$PYBIN" ]; then
  PROMPT=$(printf '%s' "$INPUT" | "$PYBIN" -c "import sys,json; print(json.load(sys.stdin).get('user_prompt',''))" 2>/dev/null || echo "")
else
  PROMPT="$INPUT"   # no python: fall back to scanning the raw payload
fi

# Fire only when the turn intends to change something substantive (code, architecture, a
# decision, a deploy). Broad on purpose -- a missed reminder is worse than a redundant one.
if echo "$PROMPT" | grep -qiE "\b(implement|fix|change|refactor|rewrite|build|add|creat|writ|edit|delet|remov|replac|migrat|deploy|push|commit|ship|releas|debug|decision|design|architect|plan)\b"; then
  echo "<user-prompt-submit-hook>LOOP (plan -> validate -> execute -> validate): for any SUBSTANTIVE unit of work, hand your PLAN to a FRESH, independent reviewer subagent to validate BEFORE you edit/write code; then execute; then have a FRESH subagent validate the result. Skip only for trivial / read-only / analysis / conversational turns. This discipline must not fall out of context.</user-prompt-submit-hook>"
fi
exit 0
