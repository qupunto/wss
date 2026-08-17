#!/usr/bin/env bash
# Sound cue whenever Claude Code is waiting on the user — permission prompts,
# option pickers, idle input, turn end. Sound ONLY, by decision: the banner,
# window-raising and tab-clicking of the script this descends from (in history
# at e51dbe5) were removed as preference rather than configuration, and only
# the chime came back as suite machinery.
#
# Wired from settings.json (checkout) and hooks/hooks.json (plugin) on
# Notification, Stop and PreToolUse(AskUserQuestion). Self-gating: silent
# unless the state file exists, so shipping it changes nothing until a machine
# opts in with `--wss-alerts on`. The state lives in the user's CONFIG
# directory — a machine-local preference, same reasoning as the bug inbox, and
# never under the plugin root, which changes on every update.
#
# Always exits 0 and prints nothing. A cue that could fail or delay the prompt
# it announces would cost more than it is worth.

STATE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/wss/flags/WSS.ALERTS-ON"
[ -f "$STATE" ] || exit 0

# Several events can fire for one prompt (a Notification plus the idle nudge,
# a Stop plus the next question); one cue per burst. The stamp lives beside
# WSS.ALERTS-ON rather than in the shared temp dir: a fixed name in /tmp is
# another user's to own or pre-link on a multi-user box, and this suite
# refuses symlinks everywhere else it writes.
STAMP="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/wss/flags/.wss-alert.stamp"
now=$(date +%s)
last=$(cat "$STAMP" 2>/dev/null) || last=0
case $last in '' | *[!0-9]*) last=0 ;; esac
[ $((now - last)) -lt 3 ] && exit 0
mkdir -p "$(dirname "$STAMP")" 2>/dev/null || true
printf '%s' "$now" > "$STAMP" 2>/dev/null || true

# WS_ALERTS_CMD replaces the whole cue: a user's own player, or `:` — which is
# also how the contract suite exercises this hook without chiming at whoever
# runs it.
if [ -n "${WS_ALERTS_CMD:-}" ]; then
  (eval "$WS_ALERTS_CMD" >/dev/null 2>&1 &)
  exit 0
fi

# Terminal bell first: free, and terminals that do not ring still flash the tab.
printf '\a' > /dev/tty 2>/dev/null || true

# One chime, first player that exists. powershell.exe outranks paplay on
# purpose: under WSL both can exist, and WSLg routes audio to an RDP sink that
# over Remote Desktop never reaches the person sitting there — measured by the
# predecessor script. Detached before it plays, so the hook returns while the
# sound is still sounding.
chime() {
  if command -v afplay >/dev/null 2>&1; then
    afplay /System/Library/Sounds/Ping.aiff
  elif command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command \
      "try { (New-Object Media.SoundPlayer 'C:\Windows\Media\Windows Notify System Generic.wav').PlaySync() } catch { [console]::beep(880,200) }"
  elif command -v paplay >/dev/null 2>&1; then
    paplay /usr/share/sounds/freedesktop/stereo/message.oga
  elif command -v aplay >/dev/null 2>&1; then
    aplay -q /usr/share/sounds/alsa/Front_Center.wav
  fi
}
(chime >/dev/null 2>&1 &)

exit 0
