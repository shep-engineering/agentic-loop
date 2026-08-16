#!/usr/bin/env bash
# install-ledger.sh — install (or uninstall) an append-only validation ledger
# into a target git repo, composing with existing hooks or refusing cleanly.
#
# Usage:
#   install-ledger.sh <target-repo>            install
#   install-ledger.sh --uninstall <target-repo>  remove guard, restore hooks state
#   install-ledger.sh --purge <target-repo>      uninstall AND delete the ledger content
#
# Design notes:
#   - Detects your repo's hook setup by resolved absolute path, so it composes with an
#     existing .githooks dir instead of clobbering it.
#   - Refuses (rather than silently breaking) if the repo already uses a classic
#     .git/hooks/pre-commit, husky, or a hooksPath pointing somewhere else.
#   - Uninstall only unsets core.hooksPath if THIS installer set it.
#   - One ledger-path variable feeds both the created file and the guard template.
#   - On any failure, rolls back every step it performed.
#   - If the repo has a git remote, it advises committing the ledger via a branch/PR
#     (so the append-only record can be reviewed), rather than straight to the trunk.

set -u
LEDGER_REL="validation-log/ledger.md"          # single source of truth
LEDGER_DIR_REL="validation-log"
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TPL="${KIT_DIR}/ledger-templates"
STATE_REL=".githooks/.ledger-install"          # records what we did, for uninstall

die(){ echo "REFUSED: $*" >&2; exit 2; }
info(){ echo "[install-ledger] $*"; }

# ---- args ----
MODE=install; PURGE=0
case "${1:-}" in
  --uninstall) MODE=uninstall; shift;;
  --purge) MODE=uninstall; PURGE=1; shift;;
esac
TARGET="${1:-}"
[ -n "$TARGET" ] || die "no target repo given. Usage: install-ledger.sh [--uninstall|--purge] <repo>"
[ -d "$TARGET" ] || die "target '$TARGET' is not a directory."
cd "$TARGET" || die "cannot cd to '$TARGET'."

# ---- precondition: git repo ----
git rev-parse --git-dir >/dev/null 2>&1 || die "'$TARGET' is not a git repo. Run 'git init' yourself first if intended."
TOP="$(git rev-parse --show-toplevel)"
cd "$TOP" || die "cannot cd to git toplevel."

# ============================ UNINSTALL ============================
if [ "$MODE" = uninstall ]; then
  # Parse the state file, never source it (sourcing = arbitrary code execution). It only
  # ever holds WE_SET_HOOKSPATH=0|1.
  if [ -f "$STATE_REL" ]; then
    WE_SET_HOOKSPATH="$(sed -n 's/^WE_SET_HOOKSPATH=//p' "$STATE_REL" | head -1)"
  fi
  WE_SET_HOOKSPATH="${WE_SET_HOOKSPATH:-0}"
  # remove our guard (worktree + index, so no dangling staged entry)
  if [ -f .githooks/pre-commit ] && grep -q "Append-only guard for the validation-log ledger" .githooks/pre-commit 2>/dev/null; then
    git rm --cached -f .githooks/pre-commit >/dev/null 2>&1
    rm -f .githooks/pre-commit && info "removed .githooks/pre-commit"
  fi
  # restore hooksPath only if WE set it
  if [ "${WE_SET_HOOKSPATH:-0}" = 1 ]; then
    git config --unset core.hooksPath 2>/dev/null && info "unset core.hooksPath (we had set it)"
  else
    info "left core.hooksPath as-is (we did not set it)"
  fi
  rm -f "$STATE_REL"
  if [ "$PURGE" = 1 ]; then rm -rf "$LEDGER_DIR_REL" && info "PURGED $LEDGER_DIR_REL"; else info "kept ledger content ($LEDGER_DIR_REL) as an audit record"; fi
  info "uninstall complete."
  exit 0
fi

# ============================ INSTALL ============================
# idempotency: already installed?
if [ -f "$LEDGER_REL" ] && [ -f .githooks/pre-commit ] && grep -q "Append-only guard for the validation-log ledger" .githooks/pre-commit 2>/dev/null; then
  info "already installed (ledger + guard present). No changes."
  exit 0
fi

# ---- hook-setup detection: compose or refuse ----
CUR_HP="$(git config core.hooksPath || true)"
WE_SET_HOOKSPATH=0
if [ -n "$CUR_HP" ]; then
  # resolve to absolute for comparison
  case "$CUR_HP" in
    /*|[A-Za-z]:*) ABS_HP="$CUR_HP";;                 # already absolute (unix or windows)
    *) ABS_HP="$TOP/$CUR_HP";;                        # relative to toplevel
  esac
  # normalize slashes + strip trailing slash for compare
  norm(){ printf '%s' "$1" | tr '\\' '/' | sed 's://*:/:g; s:/$::'; }
  N_HP="$(norm "$ABS_HP")"; N_GH="$(norm "$TOP/.githooks")"
  case "$N_HP" in
    "$N_GH")
      # hooksPath already points at .githooks — compose IF no pre-commit there
      if [ -f "$TOP/.githooks/pre-commit" ]; then
        die "existing .githooks/pre-commit found; will not clobber. Merge the append-guard manually."
      fi
      info "composing: hooksPath already => .githooks, adding pre-commit alongside existing hooks."
      ;;
    *".husky"*|*".husky/_"*)
      die "husky detected (core.hooksPath='$CUR_HP'). Installing would disable husky. Add the guard to husky manually.";;
    *)
      die "core.hooksPath is set to '$CUR_HP' (not .githooks). Refusing to override it. Compose the guard there manually.";;
  esac
else
  # no hooksPath. Classic .git/hooks/pre-commit would be silently disabled if we set hooksPath
  if [ -x .git/hooks/pre-commit ] || [ -f .git/hooks/pre-commit ]; then
    die "a classic .git/hooks/pre-commit exists; setting core.hooksPath would silently disable it. Resolve manually."
  fi
  info "no hooks framework; will set core.hooksPath=.githooks."
fi

# ---- remote check: if the repo has a remote, advise branch/PR for the ledger ----
HAS_REMOTE=0; [ -n "$(git remote)" ] && HAS_REMOTE=1
if [ "$HAS_REMOTE" = 1 ]; then
  info "NOTE: '$TOP' has a git remote."
  info "      Consider committing the ledger via a feature branch + PR so the append-only"
  info "      record gets reviewed, rather than pushing straight to your default branch."
  info "      (The installer just creates the files; you choose how to commit them.)"
  TRUNK_OK=0
else
  TRUNK_OK=1
fi

# ---- install steps, with rollback on any failure ----
CREATED_DIR=0; SET_HP=0; WROTE_HOOK=0; MADE_GHDIR=0
rollback(){
  info "rolling back..."
  if [ "$WROTE_HOOK" = 1 ]; then
    git rm --cached -f .githooks/pre-commit >/dev/null 2>&1   # reverse the git add
    rm -f .githooks/pre-commit
  fi
  [ "$MADE_GHDIR" = 1 ] && rmdir .githooks 2>/dev/null        # only if we created it and it's now empty
  [ "$SET_HP" = 1 ] && git config --unset core.hooksPath 2>/dev/null
  [ "$CREATED_DIR" = 1 ] && rm -rf "$LEDGER_DIR_REL"
  rm -f "$STATE_REL"
  die "install failed; rolled back."
}

mkdir -p "$LEDGER_DIR_REL" || rollback; CREATED_DIR=1
[ -f "$LEDGER_REL" ] || cp "$TPL/ledger.md" "$LEDGER_REL" || rollback
cp "$TPL/README.md" "$LEDGER_DIR_REL/README.md" || rollback
[ -d .githooks ] || { mkdir -p .githooks && MADE_GHDIR=1; } || rollback
# template the single LEDGER path into the guard
sed "s|__LEDGER_PATH__|$LEDGER_REL|g" "$TPL/pre-commit" > .githooks/pre-commit || rollback
WROTE_HOOK=1
chmod +x .githooks/pre-commit || rollback
if [ -z "$CUR_HP" ]; then git config core.hooksPath .githooks || rollback; SET_HP=1; WE_SET_HOOKSPATH=1; fi
# keep the internal state file out of the repo
if [ -f .gitignore ]; then grep -qxF '.githooks/.ledger-install' .gitignore || printf '.githooks/.ledger-install\n' >> .gitignore; else printf '.githooks/.ledger-install\n' > .gitignore; fi
# Stage all install artifacts together so the user sees one coherent set to commit,
# and set the durable exec bit on the hook (mode 100755 in the index).
git add .githooks/pre-commit "$LEDGER_REL" "$LEDGER_DIR_REL/README.md" .gitignore 2>/dev/null
git update-index --chmod=+x .githooks/pre-commit 2>/dev/null
# record state for uninstall — gitignored above, never committed
printf 'WE_SET_HOOKSPATH=%s\n' "$WE_SET_HOOKSPATH" > "$STATE_REL"

info "installed: ledger=$LEDGER_REL guard=.githooks/pre-commit hooksPath_set=$SET_HP trunk_ok=$TRUNK_OK"
info "staged the new files; the .ledger-install state file is gitignored."
info "next: commit the staged files (on a BRANCH if trunk_ok=0), then this repo is Rule-6 enabled."
exit 0
