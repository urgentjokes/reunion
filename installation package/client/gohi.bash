# go/hi Terminal Logging Integration for bash
# Captures command string, timestamp, execution duration, and exit code.

GOHI_CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOHI_SPOOL_DIR="$HOME/.gohi"
GOHI_PID_FILE="$GOHI_SPOOL_DIR/daemon.pid"
GOHI_SPOOL_FILE="$GOHI_SPOOL_DIR/spool.log"
GOHI_PREFIX="${GOHI_PROMPT_PREFIX:-(Hello)}"

# 1. Ensure the background daemon is running
_gohi_ensure_daemon() {
    local running=0
    if [ -f "$GOHI_PID_FILE" ]; then
        local pid
        pid=$(cat "$GOHI_PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            running=1
        fi
    fi

    if [ "$running" -eq 0 ]; then
        mkdir -p "$GOHI_SPOOL_DIR"
        if [ -f "$GOHI_CLIENT_DIR/gohi-daemon.py" ]; then
            nohup python3 "$GOHI_CLIENT_DIR/gohi-daemon.py" >/dev/null 2>&1 &
        fi
    fi
}

# 2. Configure prompt to display prefix before existing prompt
_gohi_set_prompt() {
    case "$PS1" in
        *"$GOHI_PREFIX"*)
            return
            ;;
        $'\n'*)
            PS1=$'\n'"$GOHI_PREFIX "'${PS1#$'\n'}'
            ;;
        *)
            PS1="$GOHI_PREFIX $PS1"
            ;;
    esac
}

# 3. Preexec hook via DEBUG trap
_gohi_preexec() {
    if [ "$_gohi_in_trap" = 1 ] || [ "$_gohi_in_prompt" = 1 ]; then
        return
    fi
    _gohi_in_trap=1

    case "$BASH_COMMAND" in
        _gohi*|"$PROMPT_COMMAND")
            _gohi_in_trap=0
            return
            ;;
    esac

    if [ -z "$_gohi_cmd" ]; then
        _gohi_cmd="$BASH_COMMAND"
        _gohi_time=$(date "+%Y-%m-%d %H:%M:%S")
        if [ -n "$EPOCHREALTIME" ]; then
            _gohi_start_time="$EPOCHREALTIME"
        else
            _gohi_start_time=$(date +%s)
        fi
    fi

    _gohi_in_trap=0
}

# 4. Precmd hook via PROMPT_COMMAND
_gohi_precmd() {
    local exit_code=$?
    _gohi_in_prompt=1

    if [ -n "$_gohi_cmd" ]; then
        local duration_str="0.00s"

        if [ -n "$_gohi_start_time" ]; then
            if [ -n "$EPOCHREALTIME" ]; then
                local end_time="$EPOCHREALTIME"
                duration_str=$(python3 -c "
diff = float('$end_time') - float('$_gohi_start_time')
if diff >= 60:
    m = int(diff // 60)
    s = int(diff % 60)
    print(f'{m}m {s}s')
else:
    print(f'{diff:.3f}s')
" 2>/dev/null || echo "0.00s")
            else
                local diff=$(( $(date +%s) - _gohi_start_time ))
                duration_str="${diff}s"
            fi
        fi

        # Write to spool
        python3 -c "
import json, os, sys
entry = {
    'command': sys.argv[1],
    'time': sys.argv[2],
    'duration': sys.argv[3],
    'exit_code': int(sys.argv[4])
}
spool = os.path.expanduser('~/.gohi/spool.log')
with open(spool, 'a', encoding='utf-8') as f:
    f.write(json.dumps(entry) + '\n')
" "$_gohi_cmd" "$_gohi_time" "$duration_str" "$exit_code" 2>/dev/null

        unset _gohi_cmd
        unset _gohi_start_time
        unset _gohi_time
    fi

    _gohi_set_prompt
    _gohi_in_prompt=0
}

_gohi_ensure_daemon
PROMPT_COMMAND="_gohi_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
_gohi_set_prompt

# Manual launch function for the daemon
unalias hello 2>/dev/null
hello() {
    "$GOHI_CLIENT_DIR/gohi-ctl" open 2>/dev/null || "$GOHI_CLIENT_DIR/gohi-ctl" start
}

_gohi_cmd=""
_gohi_in_prompt=0
_gohi_in_trap=0
trap '_gohi_preexec' DEBUG
