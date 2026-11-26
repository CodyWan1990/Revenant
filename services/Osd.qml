pragma Singleton

import QtQuick
import Quickshell.Services.Pipewire
import "." as Services

/// On-screen display for volume / mic changes (modelled on Dux Shell's OSD,
/// MIT). It watches PipeWire, not keybinds, so it reacts to every source of
/// change: the Mod+F10–F12 pactl binds, media keys, apps, other mixers.
///
/// panels/OsdPopup.qml (one per bar) renders `active` on the focused screen.
QtObject {
    id: root

    // ─── What the popup shows ───
    property string kind: ""          // "volume" | "mic"
    property string icon: ""
    property real value: 0            // percent; may exceed 100 when over-amplified; < 0 = no bar
    /// Text instead of the level bar (e.g. "Caps Lock on"); "" = show the bar.
    property string message: ""
    property bool muted: false
    property bool active: false
    /// Bumped on every show() so the popup can replay its entrance even while
    /// already visible (a held volume key fires many changes).
    property int serial: 0

    readonly property int hideAfterMs: Services.Settings.osdTimeoutMs

    // ─── Suppression inputs ───
    /// True for the first moments after start-up: PipeWire reports the
    /// current volume as a "change" when the shell first binds to it.
    property bool startupQuiet: true
    /// Date.now() until which changes come from the shell's own controls
    /// (the audio dropdown's sliders call suppressFor()).
    property double suppressedUntil: 0

    /// Call from a control the user is already looking at, e.g. a slider.
    function suppressFor(ms) {
        suppressedUntil = Math.max(suppressedUntil, Date.now() + ms);
    }

    /// Whether a change of this `kind` ("volume" | "mic") should pop the OSD:
    /// not at start-up, not while the shell's own slider is moving, and not
    /// over the audio dropdown (which already shows both levels). Same rule
    /// for both kinds; `kind` is passed so a per-kind rule stays a one-liner.
    function shouldShow(kind) {
        // Settings ▸ Volume popup.
        if (!Services.Settings.osdEnabled) return false;
        if (kind === "mic" && !Services.Settings.osdMic) return false;
        // Start-up: PipeWire reports the current levels as changes.
        if (root.startupQuiet) return false;
        // The change came from the shell's own slider; the user is watching it.
        if (Date.now() < root.suppressedUntil) return false;
        // The audio dropdown already shows live volume and mic state, so don't
        // cover it. Any other dropdown or panel: still show (a volume key
        // pressed with the weather dropdown open deserves feedback).
        if (Services.Ui.openPopup?.popupKind === "audio") return false;
        return true;
    }

    function show(k, glyph, percent, isMuted) {
        if (!shouldShow(k)) return;
        kind = k;
        icon = glyph;
        value = percent;
        muted = isMuted;
        message = "";
        active = true;
        serial++;
        hideTimer.restart();
    }

    /// A message OSD with no level bar (Caps Lock, layout switches, …).
    function showMessage(k, glyph, text) {
        if (!shouldShow(k)) return;
        kind = k;
        icon = glyph;
        value = -1;
        muted = false;
        message = text;
        active = true;
        serial++;
        hideTimer.restart();
    }

    // ─── Sources ───
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function volumeChanged() {
        const a = root.sink?.audio;
        if (!a) return;
        const pct = Math.round(a.volume * 100);
        const key = a.muted ? "vol-muted" : pct < 33 ? "vol-low" : pct < 66 ? "vol-med" : "vol-high";
        show("volume", Services.Icons.glyph(key, "nerd"), pct, a.muted);
    }

    function micChanged() {
        const a = root.source?.audio;
        if (!a) return;
        show("mic", Services.Icons.glyph(a.muted ? "mic-muted" : "mic", "nerd"),
             Math.round(a.volume * 100), a.muted);
    }

    // Bound so .audio stays live even when no audio widget is on the bar.
    property PwObjectTracker tracker: PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    property Connections sinkWatch: Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.volumeChanged(); }
        function onMutedChanged() { root.volumeChanged(); }
    }

    // Mic: mute toggles only — its level rarely changes outside the dropdown.
    property Connections sourceWatch: Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() { root.micChanged(); }
    }

    property Timer hideTimer: Timer {
        interval: root.hideAfterMs
        onTriggered: root.active = false
    }

    property Timer startupTimer: Timer {
        interval: 2000
        running: true
        onTriggered: root.startupQuiet = false
    }
}
