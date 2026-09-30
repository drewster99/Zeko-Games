#!/bin/bash
# Idle auto-save for this repo, driven by Claude Code hooks:
#   arm     - Stop hook: Claude finished a turn; start the idle timer.
#   cancel  - UserPromptSubmit / PreToolUse hooks: activity resumed; stop the timer.
#   wait    - internal: the detached timer process started by `arm`.
# If the timer runs out, the repo is saved: every change is committed and pushed.
# Activity is logged to claude-idle-autosave.log inside the repo's .git directory.
set -uo pipefail

IDLE_SECONDS="${GREENBEAN_AUTOSAVE_IDLE_SECONDS:-1800}"
REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
if ! GIT_DIR="$(git -C "$REPO_DIR" rev-parse --absolute-git-dir)"; then
    echo "idle-autosave: $REPO_DIR is not a git repository" >&2
    exit 1
fi
TOKEN_FILE="$GIT_DIR/claude-idle-autosave.token"
PID_FILE="$GIT_DIR/claude-idle-autosave.pid"
LOG_FILE="$GIT_DIR/claude-idle-autosave.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE"
}

notify() {
    if ! osascript -e "display notification \"$1\" with title \"Greenbean auto-save\"" > /dev/null 2>&1; then
        log "could not show notification: $1"
    fi
}

fail() {
    log "FAILED: $1"
    notify "Auto-save failed: $1 (see .git/claude-idle-autosave.log)"
}

cancel_timer() {
    rm -f "$TOKEN_FILE"
    if [ -f "$PID_FILE" ]; then
        local timer_pid
        timer_pid="$(cat "$PID_FILE")"
        rm -f "$PID_FILE"
        # The timer ends its own sleep when terminated (see `wait` below).
        if kill -0 "$timer_pid" 2> /dev/null; then
            kill "$timer_pid"
        fi
    fi
}

save_repo() {
    cd "$REPO_DIR" || { fail "cannot open $REPO_DIR"; return 1; }

    if [ -n "$(git status --porcelain)" ]; then
        local changed_files
        changed_files="$(git status --porcelain | cut -c4-)"
        git add -A >> "$LOG_FILE" 2>&1 || { fail "git add failed"; return 1; }
        git commit -q -m "Auto-save after $((IDLE_SECONDS / 60)) minutes idle" -m "$changed_files" >> "$LOG_FILE" 2>&1 \
            || { fail "git commit failed"; return 1; }
        log "committed: $(git log -1 --format='%h %s')"
    fi

    if ! git rev-parse --abbrev-ref '@{upstream}' > /dev/null 2>&1; then
        fail "branch $(git branch --show-current) has no upstream to push to"
        return 1
    fi
    if [ -z "$(git log '@{upstream}..HEAD' --oneline)" ]; then
        log "nothing to save"
        return 0
    fi
    git push -q >> "$LOG_FILE" 2>&1 || { fail "git push failed"; return 1; }
    log "pushed $(git rev-parse --short HEAD)"
    notify "Saved and pushed $(git rev-parse --short HEAD)"
}

case "${1:-}" in
    arm)
        cancel_timer
        token="$$-$(date +%s)"
        echo "$token" > "$TOKEN_FILE"
        # Fully detached, with no inherited stdio, so the hook returns immediately.
        nohup "$0" wait "$token" < /dev/null >> "$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        ;;
    cancel)
        cancel_timer
        ;;
    wait)
        token="${2:?wait needs the token it was armed with}"
        sleep "$IDLE_SECONDS" &
        sleep_pid=$!
        trap 'kill "$sleep_pid"; exit 0' TERM
        wait "$sleep_pid"
        trap - TERM
        if [ "$(cat "$TOKEN_FILE" 2> /dev/null)" != "$token" ]; then
            log "timer $token was superseded"
            exit 0
        fi
        # Past this point a cancel must not kill us mid-commit or mid-push.
        rm -f "$TOKEN_FILE" "$PID_FILE"
        log "idle for $IDLE_SECONDS seconds; saving"
        save_repo
        ;;
    *)
        echo "usage: $0 arm|cancel" >&2
        exit 2
        ;;
esac
