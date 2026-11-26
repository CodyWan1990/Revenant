import QtQuick
import Quickshell
import Quickshell.Io
import "panels" as Panels

/// Regression test for panels/PolkitPanel.qml with a fake AuthFlow (no real
/// polkit agent is ever registered in tests): it opens on a request, submits
/// and clears the password, stays open on failure, closes on completion
/// without cancelling, and cancels a request it is closed on.
/// Run with scripts/dev/run-qs-tests.sh.
ShellRoot {
    id: root
    property int failures: 0
    function check(cond, what) {
        if (!cond) { console.warn("FAIL: " + what); failures++; }
        else console.warn("  ok: " + what);
    }

    component FakeFlow: QtObject {
        property string message: "Authentication is needed to run `true' as the super user"
        property string actionId: "org.freedesktop.policykit.exec"
        property var identities: []
        property var selectedIdentity: null
        property bool isResponseRequired: true
        property string inputPrompt: "Password: "
        property bool responseVisible: false
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        property bool isCompleted: false
        property bool failed: false
        property var submitted: []
        property int cancels: 0
        function submit(value) { submitted = submitted.concat(value); }
        function cancelAuthenticationRequest() { cancels++; }
    }
    FakeFlow { id: first }
    FakeFlow { id: second }

    Panels.PolkitPanel { id: panel; flow: null }

    // tests/bin/i3-msg logs the commands the panel sends i3 (never the real one).
    FileView { id: i3Log; path: Quickshell.env("HOME") + "/i3-msg.log"; blockLoading: true }
    function lastResize() {
        i3Log.reload();
        const lines = i3Log.text().split("\n").filter(line => line.includes("resize set"));
        return lines[lines.length - 1] ?? "";
    }

    function field() {
        const find = item => {
            if (!item) return null;
            if (item.objectName === "polkitPassword") return item;
            for (const child of (item.children ?? [])) { const hit = find(child); if (hit) return hit; }
            return null;
        };
        return find(panel.contentItem);
    }

    property int step: 0
    function advance() {
        switch (step) {
        case 0:
            check(!panel.isOpen, "closed with no request");
            panel.flow = first;
            break;
        case 1:
            check(panel.isOpen, "a request opens it");
            check(field()?.placeholder === "Password", "the prompt's label, without its colon");
            field().text = "hunter2";
            panel.submit();
            check(first.submitted.join() === "hunter2", "Enter submits the typed password");
            check(field().text === "", "and the field is cleared at once");
            first.failed = true;
            first.supplementaryMessage = "Sorry, try again.";
            first.supplementaryIsError = true;
            break;
        case 2:
            check(panel.isOpen, "a wrong password keeps it open");
            check(lastResize().includes("resize set " + Math.round(panel.implicitWidth) + " px "
                    + Math.round(panel.implicitHeight) + " px"),
                  "i3 is asked to fit the window to the content (" + lastResize() + ")");
            first.isCompleted = true;
            break;
        case 3:
            check(!panel.isOpen, "polkit finishing closes it");
            check(first.cancels === 0, "without cancelling the finished request");
            panel.flow = second;
            break;
        case 4:
            check(panel.isOpen, "the next request opens it again");
            field().text = "typed";
            panel.close();      // Esc / Cancel
            break;
        case 5:
            check(second.cancels === 1, "closing it cancels the pending request");
            check(field().text === "", "and drops what was typed");
            panel.flow = null;
            console.warn(failures === 0 ? "RESULT: all polkit-panel tests passed"
                                        : "RESULT: " + failures + " polkit-panel test(s) FAILED");
            poll.stop();
            return;
        }
        step++;
    }

    Timer {
        id: poll
        interval: 150
        repeat: true
        running: true
        property int ticks: 0
        onTriggered: {
            if (++ticks > 100) { console.warn("RESULT: polkit-panel tests FAILED — timed out at step " + root.step); stop(); return; }
            try { root.advance(); }
            catch (error) { console.warn("RESULT: polkit-panel tests FAILED with " + error); stop(); }
        }
    }
}
