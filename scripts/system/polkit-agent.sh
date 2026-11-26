#!/bin/sh
# The system's own polkit agent (password prompts for pkexec, mounts, …),
# for when the shell is not the agent.
#
#   polkit-agent.sh start   start the first installed agent, unless one runs
#   polkit-agent.sh stop    stop any of them, so the shell can register
#
# Only one agent can register per session; one that starts second fails to
# register. The shell (Settings → Admin prompts) runs `stop` before it
# registers its own, and `start` when switched back. Run `start` at login
# (an i3 `exec`) if the shell isn't the agent.

# Agent binaries, most common first; each is searched in these directories.
names="polkit-gnome-authentication-agent-1 lxqt-policykit-agent lxpolkit polkit-mate-authentication-agent-1 polkit-kde-authentication-agent-1"
dirs="/usr/lib/polkit-gnome /usr/lib/policykit-1-gnome /usr/libexec /usr/lib/x86_64-linux-gnu/libexec /usr/lib/mate-polkit /usr/libexec/polkit-mate /usr/lib/polkit-kde /usr/bin"

running() {
    for name in $names; do pgrep -f "$name" >/dev/null && return 0; done
    return 1
}

case "${1:-start}" in
    start)
        running && exit 0
        for name in $names; do
            for dir in $dirs; do
                [ -x "$dir/$name" ] && { setsid -f "$dir/$name" >/dev/null 2>&1; exit 0; }
            done
            command -v "$name" >/dev/null 2>&1 && { setsid -f "$name" >/dev/null 2>&1; exit 0; }
        done
        echo "polkit-agent: no polkit agent installed (e.g. polkit-gnome, lxpolkit)" >&2
        exit 1 ;;
    stop)
        for name in $names; do pkill -f "$name"; done
        # Wait for it to drop its registration before another agent tries.
        for _ in $(seq 20); do running || exit 0; sleep 0.1; done
        exit 0 ;;
    *)
        echo "usage: ${0##*/} start|stop" >&2; exit 2 ;;
esac
