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

# 3. Background append function
_gohi_pi_append() {
    local cmd="$1"
    local time_str="$2"
    local duration="$3"
    local exit_code="$4"
    local target_html="$5"
    local entry_id="$6"

    python3 -c "
import os, sys, html

cmd = sys.argv[1]
time_str = sys.argv[2]
duration = sys.argv[3]
exit_code = sys.argv[4]
html_path = sys.argv[5]
entry_id = sys.argv[6]

if not os.path.exists(html_path):
    sys.exit(0)

try:
    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()

    marker = '<!-- GOHI_ENTRIES_END -->'
    if marker not in content:
        marker = '</tbody>'

    is_success = str(exit_code) == '0'
    badge_class = 'badge-success' if is_success else 'badge-error'
    cmd_esc = html.escape(cmd)
    time_esc = html.escape(time_str)
    dur_esc = html.escape(duration)
    code_esc = html.escape(str(exit_code))
    eid_esc = html.escape(str(entry_id))

    new_row = f'''            <tr class=\"log-row\" data-id=\"{eid_esc}\">
              <td class=\"command-cell\">
                <a href=\"#\" class=\"command-link\" onclick=\"copyCommand(this, event)\" data-command=\"{cmd_esc}\">
                  <span>{cmd_esc}</span>
                  <span class=\"copy-icon\">📋</span>
                </a>
              </td>
              <td class=\"time-cell\">{time_esc}</td>
              <td class=\"duration-cell\">{dur_esc}</td>
              <td class=\"error-cell\">
                <span class=\"badge {badge_class}\">{code_esc}</span>
              </td>
              <td class=\"action-cell\">
                <button class=\"delete-btn\" onclick=\"deleteEntry(this, event)\" title=\"Delete command\" aria-label=\"Delete\">
                  <svg width=\"15\" height=\"15\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">
                    <polyline points=\"3 6 5 6 21 6\"></polyline>
                    <path d=\"M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2\"></path>
                    <line x1=\"10\" y1=\"11\" x2=\"10\" y2=\"17\"></line>
                    <line x1=\"14\" y1=\"11\" x2=\"14\" y2=\"17\"></line>
                  </svg>
                </button>
              </td>
            </tr>\n'''

    parts = content.split(marker, 1)
    if len(parts) == 2:
        new_content = parts[0] + new_row + marker + parts[1]
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
except Exception:
    pass
" "$cmd" "$time_str" "$duration" "$exit_code" "$target_html" "$entry_id" >/dev/null 2>&1 &
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

    _gohi_pi_preexec() {
        if [ -n "$_gohi_pi_in_prompt" ]; then
            return
        fi
        # Ignore prompt commands and gohi internal functions
        case "$BASH_COMMAND" in
            _gohi*|"$PROMPT_COMMAND")
                return
                ;;
        esac
        _gohi_pi_cmd="$BASH_COMMAND"
        _gohi_pi_start=$(/usr/bin/python3 -c 'import time; print(time.time())' 2>/dev/null || date +%s)
        _gohi_pi_time=$(date "+%Y-%m-%d %H:%M:%S")
    }

    _gohi_pi_precmd() {
        local exit_code=$?
        _gohi_pi_in_prompt=1

        if [ -n "$_gohi_pi_cmd" ]; then
            local duration="0.00s"
            if [ -n "$_gohi_pi_start" ]; then
                duration=$(/usr/bin/python3 -c "
import time
diff = time.time() - float('$_gohi_pi_start')
if diff >= 60:
    m = int(diff // 60)
    s = int(diff % 60)
    print(f'{m}m {s}s')
else:
    print(f'{diff:.3f}s')
" 2>/dev/null || echo "0.00s")
            fi
            local entry_id=$(date +%s%N 2>/dev/null || date +%s)
            _gohi_pi_append "$_gohi_pi_cmd" "$_gohi_pi_time" "$duration" "$exit_code" "$GOHI_PI_HTML" "$entry_id"
            unset _gohi_pi_cmd
            unset _gohi_pi_start
            unset _gohi_pi_time
        fi

        _gohi_pi_set_prompt
        unset _gohi_pi_in_prompt
    }

    _gohi_pi_set_prompt
    trap '_gohi_pi_preexec' DEBUG
    PROMPT_COMMAND="_gohi_pi_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
