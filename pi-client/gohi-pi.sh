# go/hi — Local Terminal Logger for Raspberry Pi
# Zero-server, zero-daemon: appends directly to a local HTML file.
# Works in both bash and zsh.

GOHI_PI_DIR="${GOHI_PI_DIR:-$HOME/go-hi/pi-client}"
GOHI_PI_HTML="${GOHI_PI_HTML:-$HOME/pi-history.html}"

# 1. Initialize HTML file if not already present
if [ ! -f "$GOHI_PI_HTML" ]; then
    if [ -f "$GOHI_PI_DIR/index.html" ]; then
        cp "$GOHI_PI_DIR/index.html" "$GOHI_PI_HTML"
    fi
fi

# 2. Prompt Prefix Configuration
_gohi_pi_set_prompt() {
    case "$PS1" in
        *"(Hello)"*)
            return
            ;;
        *)
            PS1="(Hello) $PS1"
            ;;
    esac
}

# 3. Background append function (runs detached subshell to suppress bash job control messages)
_gohi_pi_append() {
    local cmd="$1"
    local time_str="$2"
    local duration="$3"
    local exit_code="$4"
    local target_html="$5"
    local entry_id="$6"

    ( python3 "$GOHI_PI_DIR/append.py" "$cmd" "$time_str" "$duration" "$exit_code" "$target_html" "$entry_id" >/dev/null 2>&1 & )
}

# 4. Shell Specific Hooks
if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz add-zsh-hook
    zmodload zsh/datetime 2>/dev/null

    _gohi_pi_preexec() {
        _gohi_pi_cmd="$1"
        if (( $+EPOCHREALTIME )); then
            _gohi_pi_start=$EPOCHREALTIME
        else
            _gohi_pi_start=$(date +%s)
        fi
        _gohi_pi_time=$(date "+%Y-%m-%d %H:%M:%S")
    }

    _gohi_pi_precmd() {
        local exit_code=$?
        if [ -n "$_gohi_pi_cmd" ]; then
            local duration="0.000s"
            if [ -n "$_gohi_pi_start" ]; then
                if (( $+EPOCHREALTIME )); then
                    local diff=$(( EPOCHREALTIME - _gohi_pi_start ))
                    duration=$(printf "%.3fs" "$diff")
                else
                    duration="$(( $(date +%s) - _gohi_pi_start ))s"
                fi
            fi
            local entry_id=$(date +%s%N 2>/dev/null || date +%s)
            _gohi_pi_append "$_gohi_pi_cmd" "$_gohi_pi_time" "$duration" "$exit_code" "$GOHI_PI_HTML" "$entry_id"
            unset _gohi_pi_cmd
            unset _gohi_pi_start
            unset _gohi_pi_time
        fi
        _gohi_pi_set_prompt
    }

    _gohi_pi_set_prompt
    add-zsh-hook preexec _gohi_pi_preexec
    add-zsh-hook precmd _gohi_pi_precmd

elif [ -n "$BASH_VERSION" ]; then
    _gohi_pi_in_trap=0
    _gohi_pi_in_prompt=0
    _gohi_pi_cmd=""

    _gohi_pi_preexec() {
        if [ "$_gohi_pi_in_trap" -eq 1 ] || [ "$_gohi_pi_in_prompt" -eq 1 ]; then
            return
        fi
        _gohi_pi_in_trap=1

        # Ignore internal commands
        case "$BASH_COMMAND" in
            _gohi*|"$PROMPT_COMMAND")
                _gohi_pi_in_trap=0
                return
                ;;
        esac

        # Only record the first command of the pipeline/cycle
        if [ -z "$_gohi_pi_cmd" ]; then
            _gohi_pi_cmd="$BASH_COMMAND"
            _gohi_pi_time=$(date "+%Y-%m-%d %H:%M:%S")
            if [ -n "$EPOCHREALTIME" ]; then
                _gohi_pi_start="$EPOCHREALTIME"
            else
                _gohi_pi_start=$(date +%s)
            fi
        fi

        _gohi_pi_in_trap=0
    }

    _gohi_pi_precmd() {
        local exit_code=$?
        _gohi_pi_in_prompt=1

        if [ -n "$_gohi_pi_cmd" ]; then
            local duration="0.00s"
            if [ -n "$_gohi_pi_start" ]; then
                if [ -n "$EPOCHREALTIME" ]; then
                    local end_time="$EPOCHREALTIME"
                    duration=$(python3 -c "
diff = float('$end_time') - float('$_gohi_pi_start')
if diff >= 60:
    m = int(diff // 60)
    s = int(diff % 60)
    print(f'{m}m {s}s')
else:
    print(f'{diff:.3f}s')
" 2>/dev/null || echo "0.00s")
                else
                    duration="$(( $(date +%s) - _gohi_pi_start ))s"
                fi
            fi

            local entry_id=$(date +%s%N 2>/dev/null || date +%s)
            _gohi_pi_append "$_gohi_pi_cmd" "$_gohi_pi_time" "$duration" "$exit_code" "$GOHI_PI_HTML" "$entry_id"
            unset _gohi_pi_cmd
            unset _gohi_pi_start
            unset _gohi_pi_time
        fi

        _gohi_pi_set_prompt
        _gohi_pi_in_prompt=0
    }

    PROMPT_COMMAND="_gohi_pi_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
    _gohi_pi_set_prompt
    _gohi_pi_cmd=""
    _gohi_pi_in_prompt=0
    _gohi_pi_in_trap=0
    trap '_gohi_pi_preexec' DEBUG
fi
