# go/hi Terminal Logging Integration for bash
# Captures command string, timestamp, execution duration, and exit code.

GOHI_DIR="${GOHI_DIR:-$HOME/developer-stuff/go-hi}"
GOHI_SPOOL_DIR="$HOME/.gohi"
GOHI_PID_FILE="$GOHI_SPOOL_DIR/daemon.pid"
GOHI_SPOOL_FILE="$GOHI_SPOOL_DIR/spool.log"

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
        if [ -f "$GOHI_DIR/client/gohi-daemon.py" ]; then
            nohup /usr/bin/python3 "$GOHI_DIR/client/gohi-daemon.py" >/dev/null 2>&1 &
        fi
    fi
}

# 2. Configure prompt to display (Hello) before existing prompt
_gohi_set_prompt() {
    case "$PS1" in
        *"(Hello)"*)
            return
            ;;
        $'\n'*)
            PS1=$'\n(Hello) '"${PS1#$'\n'}"
            ;;
        *)
            PS1="(Hello) $PS1"
            ;;
    esac
}

# Preexec hook via DEBUG trap
_gohi_preexec() {
    # Skip if running inside precmd or prompt command
    if [ -n "$_gohi_in_prompt" ]; then
        return
    fi
    case "$BASH_COMMAND" in
        _gohi*|"$PROMPT_COMMAND")
            return
            ;;
    esac
    _gohi_cmd="$BASH_COMMAND"
    _gohi_start_time=$(/usr/bin/python3 -c 'import time; print(time.time())' 2>/dev/null || date +%s)
    _gohi_time=$(date "+%Y-%m-%d %H:%M:%S")
}

# Precmd hook via PROMPT_COMMAND
_gohi_precmd() {
    local exit_code=$?
    _gohi_in_prompt=1

    if [ -n "$_gohi_cmd" ]; then
        local end_time
        end_time=$(/usr/bin/python3 -c 'import time; print(time.time())' 2>/dev/null || date +%s)
        local duration_str="0.00s"

        if [ -n "$_gohi_start_time" ]; then
            duration_str=$(/usr/bin/python3 -c "
diff = float('$end_time') - float('$_gohi_start_time')
if diff >= 60:
    m = int(diff // 60)
    s = int(diff % 60)
    print(f'{m}m {s}s')
else:
    print(f'{diff:.3f}s')
" 2>/dev/null || echo "0.00s")
        fi

        # Write to spool
        /usr/bin/python3 -c "
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
    unset _gohi_in_prompt
}

_gohi_ensure_daemon
_gohi_set_prompt

trap '_gohi_preexec' DEBUG
PROMPT_COMMAND="_gohi_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Manual launch function for the daemon
unalias hello 2>/dev/null
hello() {
    "$GOHI_DIR/client/gohi-ctl" start
}
