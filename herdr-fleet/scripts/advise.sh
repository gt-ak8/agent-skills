#!/usr/bin/env bash
# advise.sh <agent-name | session-id | self> <question-file> [effort]
# Forks a session and asks a stronger model one question about it, read-only.
#
# The point is the fork. An advisor spawned fresh has to be told where the
# reasoning stands, and a summary of a long conversation is exactly the thing
# whose accuracy is in doubt when you need an advisor. A fork starts from the
# real history: what was actually tried, what the tool output actually said,
# which assumption was never checked. In testing, a forked advisor's first move
# was to correct the framing of the question it was asked - it could see that
# the line number in the question came from a pre-compaction summary and had
# since moved. A fresh advisor would have answered the wrong question well.
#
# Read-only by construction, not by instruction. A fork inherits the worker's
# tool permissions AND a history that reads "I am mid-implementation", so asking
# it nicely not to touch anything is the weakest possible guard - the same class
# of mistake as telling a pane which branch to integrate into and expecting it
# to infer which branch to commit on. --permission-mode plan blocks the edit
# tools outright; the disallowed list covers the shell paths that mutate.
#
# The original session and pane are untouched: --fork-session writes a new
# session file and never appends to the parent.
set -uo pipefail
TARGET="${1:?agent name, session id, or 'self'}"
QF="${2:?question file}"
EFFORT="${3:-high}"
MODEL="${ADVISOR_MODEL:-claude-opus-5}"
HERE="$(cd "$(dirname "$0")" && pwd)"
# Resolved before the cd below, and keyed to the project rather than to cwd -
# reading the register from wherever advise.sh happened to be called is what
# made it miss pinned session ids and fall back to guessing. See fleet-reg.sh.
REG="${REG:-$("$HERE/fleet-reg.sh")}"

[ -f "$QF" ] || { echo "no such question file: $QF" >&2; exit 2; }

is_uuid() {
  case "$1" in
    [0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*) return 0 ;;
    *) return 1 ;;
  esac
}

SID=""; CWD=""
if [ "$TARGET" = self ]; then
  # CLAUDE_SESSION_ID is not exported into a pane's shell, so an orchestrator
  # that wants to fork itself sets ADVISOR_SESSION_ID once from its own launch
  # command. Otherwise pass the uuid as the first argument.
  SID="${CLAUDE_SESSION_ID:-${ADVISOR_SESSION_ID:-}}"; CWD="$PWD"
  [ -n "$SID" ] || { echo "self: set ADVISOR_SESSION_ID, or pass the session id as the first argument" >&2; exit 1; }
elif is_uuid "$TARGET"; then
  SID="$TARGET"; CWD="$PWD"
else
  # fleet.tsv is name<TAB>pane<TAB>tab<TAB>cwd<TAB>session-id. Rows written
  # before session ids were pinned have only four fields.
  if [ -f "$REG" ]; then
    ROW=$(awk -F'\t' -v n="$TARGET" '$1==n {print; exit}' "$REG")
    CWD=$(printf '%s' "$ROW" | cut -f4)
    SID=$(printf '%s' "$ROW" | cut -f5)
  fi
  [ -n "$CWD" ] || CWD=$(herdr agent get "$TARGET" 2>/dev/null | jq -r '.result.agent.cwd // empty')
  [ -n "$CWD" ] || { echo "no agent '$TARGET' in $REG or in herdr" >&2; exit 1; }
  if [ -z "$SID" ]; then
    echo "advise: $TARGET has no recorded session id (launched before ids were pinned)." >&2
    echo "advise: falling back to the newest session in $CWD - verify it is the right one." >&2
    SLUG=$(printf '%s' "$CWD" | tr -c 'A-Za-z0-9' '-')
    DIR="$HOME/.claude/projects/$SLUG"
    NEWEST=$(ls -t "$DIR"/*.jsonl 2>/dev/null | head -1)
    [ -n "$NEWEST" ] || { echo "advise: no session files under $DIR" >&2; exit 1; }
    SID=$(basename "$NEWEST" .jsonl)
    echo "advise: guessed $SID ($(wc -l < "$NEWEST") turns)" >&2
  fi
fi

PREAMBLE='You are an advisor forked from this conversation, running as '"$MODEL"'.
You have the full history above - do not re-derive it, and do not re-read files
you can already see were read. You are read-only: answer the question, do not
act on it, do not edit, do not commit, do not push. If the question rests on a
premise the history shows to be wrong, say so first and answer the real
question. If the history does not settle it, say what single piece of evidence
would, and name the command that gets it. Be direct and short.

The question:
'

cd "$CWD" 2>/dev/null || { echo "cannot cd to $CWD" >&2; exit 1; }

printf '%s%s\n' "$PREAMBLE" "$(cat "$QF")" | claude \
  --resume "$SID" --fork-session \
  --model "$MODEL" --effort "$EFFORT" \
  --permission-mode plan \
  --disallowed-tools Edit Write NotebookEdit 'Bash(git push:*)' 'Bash(git commit:*)' 'Bash(gh pr merge:*)' \
  -p
RC=$?
[ $RC -eq 0 ] || echo "advise: $MODEL exited $RC (session $SID, cwd $CWD)" >&2
exit $RC
