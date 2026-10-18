# go/hi Terminal Logging Integration for zsh
# Captures command string, timestamp, execution duration, and exit code.

GOHI_CLIENT_DIR="${0:A:h}"
GOHI_SPOOL_DIR="$HOME/.gohi"
GOHI_PID_FILE="$GOHI_SPOOL_DIR/daemon.pid"
GOHI_SPOOL_FILE="$GOHI_SPOOL_DIR/spool.log"
GOHI_PREFIX="${GOHI_PROMPT_PREFIX:-(Hello)}"

autoload -Uz add-zsh-hook
zmodload zsh/datetime 2>/dev/null

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

# 3. Capture command at execution start
_gohi_preexec() {
    _gohi_cmd="$1"
    if (( $+EPOCHREALTIME )); then
        _gohi_start_time=$EPOCHREALTIME
    else
        _gohi_start_time=$(date +%s)
    fi

    if (( $+EPOCHSECONDS )); then
        _gohi_time=$(strftime "%Y-%m-%d %H:%M:%S" $EPOCHSECONDS)
    else
        _gohi_time=$(date "+%Y-%m-%d %H:%M:%S")
    fi
}

# 4. Capture exit code and duration on command completion
_gohi_precmd() {
    local exit_code=$?

    if [ -n "$_gohi_cmd" ]; then
        local duration_str="0.000s"

        if [ -n "$_gohi_start_time" ]; then
            if (( $+EPOCHREALTIME )); then
                local end_time=$EPOCHREALTIME
                local diff=$(( end_time - _gohi_start_time ))
                if (( diff >= 60 )); then
                    integer total_sec
                    total_sec=$diff
                    local min=$(( total_sec / 60 ))
                    local sec=$(( total_sec % 60 ))
                    duration_str="${min}m ${sec}s"
                else
                    duration_str=$(printf "%.3fs" "$diff")
                fi
            else
                local end_time=$(date +%s)
                local diff=$(( end_time - _gohi_start_time ))
                duration_str="${diff}s"
            fi
        fi

        # Escape command string for JSON
        local cmd_esc="${_gohi_cmd//\\/\\\\}"
        cmd_esc="${cmd_esc//\"/\\\"}"
        cmd_esc="${cmd_esc//$'\n'/\\n}"
        cmd_esc="${cmd_esc//$'\r'/\\r}"
        cmd_esc="${cmd_esc//$'\t'/\\t}"

        # Fast non-blocking write to local spool
        mkdir -p "$GOHI_SPOOL_DIR"
        printf '{"command":"%s","time":"%s","duration":"%s","exit_code":%d}\n' \
            "$cmd_esc" "$_gohi_time" "$duration_str" "$exit_code" >> "$GOHI_SPOOL_FILE" 2>/dev/null

        unset _gohi_cmd
        unset _gohi_start_time
        unset _gohi_time
    fi

    _gohi_set_prompt
}

# Initialize on shell startup
_gohi_ensure_daemon
_gohi_set_prompt

add-zsh-hook preexec _gohi_preexec
add-zsh-hook precmd _gohi_precmd

# Manual launch function for the daemon
unalias hello 2>/dev/null
hello() {
    "$GOHI_CLIENT_DIR/gohi-ctl" start
}
