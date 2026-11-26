#!/bin/sh
# Stand-in "dmenu" for clipmenu 7, which has no list/pick commands of its own.
# Its stdout is clipmenu's *selection*, so listing must print nothing there.
#   CLIP_MODE=list   copy the menu ("[N] first line", newest first) to $CLIP_OUT, select nothing
#   CLIP_MODE=pick   select the line in $CLIP_LINE (clipmenu then serves it via clipserve)
# clipmenu passes dmenu flags (-p … -l …); they are ignored.
case "${CLIP_MODE:-list}" in
    pick) cat >/dev/null; printf '%s\n' "$CLIP_LINE" ;;
    *)    cat > "${CLIP_OUT:?}" ;;
esac
