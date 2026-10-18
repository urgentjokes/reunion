# go/hi — Standalone Local Terminal Logger
# Zero-server, zero-daemon: logs shell interactions directly to a local HTML file.
# Works seamlessly in bash and zsh on Linux and macOS.

GOHI_LOCAL_DIR="${GOHI_LOCAL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" 2>/dev/null && pwd)}"
GOHI_HTML="${GOHI_HTML:-$HOME/terminal-history.html}"
GOHI_PROMPT_PREFIX="${GOHI_PROMPT_PREFIX:-(Hello)}"

# 1. Initialize HTML file if not already present
if [ ! -f "$GOHI_HTML" ]; then
    if [ -f "$GOHI_LOCAL_DIR/index.html" ]; then
        cp "$GOHI_LOCAL_DIR/index.html" "$GOHI_HTML"
    fi
fi

# 2. Prompt Prefix Configuration
_gohi_local_set_prompt() {
    case "$PS1" in
        *"$GOHI_PROMPT_PREFIX"*)
            return
            ;;
        *)
            PS1="$GOHI_PROMPT_PREFIX $PS1"
            ;;
    esac
}

# 3. Background append function (runs detached subshell to suppress bash job notifications)
_gohi_local_append() {
    local cmd="$1"
    local time_str="$2"
    local duration="$3"
    local exit_code="$4"
    local target_html="$5"
    local entry_id="$6"

    ( python3 "$GOHI_LOCAL_DIR/append.py" "$cmd" "$time_str" "$duration" "$exit_code" "$target_html" "$entry_id" >/dev/null 2>&1 & )
}

# 4. Helper function to open local HTML dashboard in browser
unalias hello 2>/dev/null || true
hello() {
    if [ -f "$GOHI_HTML" ]; then
        if command -v open >/dev/null 2>&1; then
            open "$GOHI_HTML"
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$GOHI_HTML" >/dev/null 2>&1 &
        else
            echo "Local dashboard located at: file://$GOHI_HTML"
        fi
    else
        echo "No history logged yet. Run a command to generate $GOHI_HTML"
    fi
}

# 5. Shell Specific Hooks
if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz add-zsh-hook
    zmodload zsh/datetime 2>/dev/null

    _gohi_local_preexec() {
        _gohi_cmd="$1"
        if (( $+EPOCHREALTIME )); then
            _gohi_start=$EPOCHREALTIME
        else
            _gohi_start=$(date +%s)
        fi
        _gohi_time=$(date "+%Y-%m-%d %H:%M:%S")
    }

    _gohi_local_precmd() {
        local exit_code=$?
        if [ -n "$_gohi_cmd" ]; then
            local duration="0.000s"
            if [ -n "$_gohi_start" ]; then
                if (( $+EPOCHREALTIME )); then
                    local diff=$(( EPOCHREALTIME - _gohi_start ))
                    duration=$(printf "%.3fs" "$diff")
                else
                    duration="$(( $(date +%s) - _gohi_start ))s"
                fi
            fi
            local entry_id=$(date +%s%N 2>/dev/null || date +%s)
            _gohi_local_append "$_gohi_cmd" "$_gohi_time" "$duration" "$exit_code" "$GOHI_HTML" "$entry_id"
            unset _gohi_cmd
            unset _gohi_start
            unset _gohi_time
        fi
        _gohi_local_set_prompt
    }

    _gohi_local_set_prompt
    add-zsh-hook preexec _gohi_local_preexec
    add-zsh-hook precmd _gohi_local_precmd

elif [ -n "$BASH_VERSION" ]; then
    _gohi_in_trap=0
    _gohi_in_prompt=0
    _gohi_cmd=""

    _gohi_local_preexec() {
        if [ "$_gohi_in_trap" -eq 1 ] || [ "$_gohi_in_prompt" -eq 1 ]; then
            return
        fi
        _gohi_in_trap=1

        # Ignore internal commands
        case "$BASH_COMMAND" in
            _gohi*|"$PROMPT_COMMAND")
                _gohi_in_trap=0
                return
                ;;
        esac

        # Only record the first command of the pipeline/cycle
        if [ -z "$_gohi_cmd" ]; then
            _gohi_cmd="$BASH_COMMAND"
            _gohi_time=$(date "+%Y-%m-%d %H:%M:%S")
            if [ -n "$EPOCHREALTIME" ]; then
                _gohi_start="$EPOCHREALTIME"
            else
                _gohi_start=$(date +%s)
            fi
        fi

        _gohi_in_trap=0
    }

    _gohi_local_precmd() {
        local exit_code=$?
        _gohi_in_prompt=1

        if [ -n "$_gohi_cmd" ]; then
            local duration="0.00s"
            if [ -n "$_gohi_start" ]; then
                if [ -n "$EPOCHREALTIME" ]; then
                    local end_time="$EPOCHREALTIME"
                    duration=$(python3 -c "
diff = float('$end_time') - float('$_gohi_start')
if diff >= 60:
    m = int(diff // 60)
    s = int(diff % 60)
    print(f'{m}m {s}s')
else:
    print(f'{diff:.3f}s')
" 2>/dev/null || echo "0.00s")
                else
                    duration="$(( $(date +%s) - _gohi_start ))s"
                fi
            fi

            local entry_id=$(date +%s%N 2>/dev/null || date +%s)
            _gohi_local_append "$_gohi_cmd" "$_gohi_time" "$duration" "$exit_code" "$GOHI_HTML" "$entry_id"
            unset _gohi_cmd
            unset _gohi_start
            unset _gohi_time
        fi

        _gohi_local_set_prompt
        _gohi_in_prompt=0
    }

    PROMPT_COMMAND="_gohi_local_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    _gohi_local_set_prompt
    _gohi_cmd=""
    _gohi_in_prompt=0
    _gohi_in_trap=0
    trap '_gohi_local_preexec' DEBUG
fi
