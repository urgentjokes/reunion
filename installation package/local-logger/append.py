#!/usr/bin/env python3
"""
reunion Local Logger - Appender Helper
Safely appends a command record directly to the local HTML file.
Auto-initializes the HTML file from the template if it does not yet exist.
"""

import sys
import os
import html

if len(sys.argv) < 7:
    sys.exit(0)

cmd = sys.argv[1]
time_str = sys.argv[2]
duration = sys.argv[3]
exit_code = sys.argv[4]
html_path = sys.argv[5]
entry_id = sys.argv[6]

# Auto-initialize target HTML file if missing
if not os.path.exists(html_path):
    template = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'index.html')
    if os.path.exists(template):
        try:
            with open(template, 'r', encoding='utf-8') as tf:
                base = tf.read()
            with open(html_path, 'w', encoding='utf-8') as hf:
                hf.write(base)
        except Exception:
            sys.exit(0)
    else:
        sys.exit(0)

try:
    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()

    marker = '<!-- GOHI_ENTRIES_START -->'
    if marker not in content:
        marker = '<tbody id="logBody">'

    is_success = str(exit_code) == '0'
    badge_class = 'badge-success' if is_success else 'badge-error'
    cmd_esc = html.escape(cmd)
    time_esc = html.escape(time_str)
    dur_esc = html.escape(duration)
    code_esc = html.escape(str(exit_code))
    eid_esc = html.escape(str(entry_id))

    new_row = f'''            <tr class="log-row" data-id="{eid_esc}">
              <td class="command-cell">
                <a href="#" class="command-link" onclick="copyCommand(this, event)" data-command="{cmd_esc}">
                  <span>{cmd_esc}</span>
                  <span class="copy-icon">📋</span>
                </a>
              </td>
              <td class="time-cell">{time_esc}</td>
              <td class="duration-cell">{dur_esc}</td>
              <td class="error-cell">
                <span class="badge {badge_class}">{code_esc}</span>
              </td>
              <td class="action-cell">
                <button class="delete-btn" onclick="deleteEntry(this, event)" title="Delete command" aria-label="Delete">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="3 6 5 6 21 6"></polyline>
                    <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                    <line x1="10" y1="11" x2="10" y2="17"></line>
                    <line x1="14" y1="11" x2="14" y2="17"></line>
                  </svg>
                </button>
              </td>
            </tr>\n'''

    parts = content.split(marker, 1)
    if len(parts) == 2:
        new_content = parts[0] + marker + '\n' + new_row + parts[1]
        with open(html_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
except Exception:
    pass
