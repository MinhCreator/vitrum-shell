import QtQuick
import QtQuick.Effects
import qs.services
import qs.theme
import qs.components
import "root:/lib/lock.js" as Lib

/*
 * The password field, of glass (a rounded rectangle, Tokens.radiusTile). The
 * text itself is never drawn: each character is a dot that grows in, damped,
 * and shrinks away when erased.
 *
 * Lit glass: once there is something typed the field turns on like any other
 * piece (ShellTint: frosted, a bright rim, the accent only as a light under
 * it and in the lock icon), gently, a little more with each character up to
 * eight. While PAM checks, a white light sweeps along it. A good password
 * passes the light across once more as the lock dissolves (LockView blooms
 * its light out of here).
 *
 * A wrong password: the glass lights up in Colors.danger, the dots blush red
 * and the field shakes — one damped swing, not a set of jerks — then the dots
 * go out together and the "Password" hint fades back in. Nothing overlaps on
 * the way: the dots stay until the shake is over, whatever the lock did with
 * the password. The timings are Lib.refusal's, at the motion speed. With
 * animations off the swing and the fades are left out: the red light comes
 * on, holds and goes.
 *
 * Caps Lock on: a small line icon at the right end (lock.capsLock).
 */
LockGlass {
    id: field
    required property var lock

    width: Tokens.islandHeight * 11
    height: Tokens.islandHeight * 1.4
    radius: Tokens.radiusTile
    outline: Qt.tint(Colors.alpha(Colors.text, 0.12), Colors.alpha(Colors.danger, 0.85 * flash))
    edgeLight: 0.5 + 0.3 * flash

    // ------------------------------------------------------- a refusal ---
    property real flash: 0
    property real swing: 0            // 0 → 1 over the shake
    property bool refusing: false
    property real dotsOpacity: 1
    readonly property var t: Lib.refusal(Motion.speed)
    readonly property real shake: Tokens.islandHeight * 0.42 * Math.sin(swing * Math.PI * 6) * Math.pow(1 - swing, 2)
    transform: Translate { x: field.shake }

    SequentialAnimation {
        id: refuse
        ScriptAction { script: { field.refusing = true; field.dotsOpacity = 1; dangerTint.sweep(); } }
        ParallelAnimation {
            NumberAnimation { target: field; property: "swing"; from: 0; to: 1; duration: field.t.swing; easing.type: Easing.Linear }
            SequentialAnimation {
                NumberAnimation { target: field; property: "flash"; to: 1; duration: field.t.flashIn; easing.type: Easing.OutCubic }
                PauseAnimation { duration: field.t.hold }
                NumberAnimation { target: field; property: "flash"; to: 0; duration: field.t.flashOut; easing.type: Easing.InOutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: field.t.dotsAfter }
                NumberAnimation { target: field; property: "dotsOpacity"; to: 0; duration: field.t.dotsOut; easing.type: Easing.InCubic }
            }
        }
        // The dots go while they are invisible: the ListView runs its remove
        // transition after sync() returns, so lighting them first showed the
        // old dots shrinking over the "Password" hint as it came back.
        ScriptAction { script: dots.sync(field.lock.password.length, false) }
        PauseAnimation { duration: Motion.fast + 40 }
        ScriptAction { script: { dots.sync(field.lock.password.length, false); field.refusing = false; field.dotsOpacity = 1; } }
    }
    // Animations off: no swing and no fades, but a refusal must still be seen.
    SequentialAnimation {
        id: refuseStill
        ScriptAction { script: { field.swing = 0; field.dotsOpacity = 1; field.flash = 1; } }
        PauseAnimation { duration: field.t.flashIn + field.t.hold }
        ScriptAction { script: { field.flash = 0; dots.sync(field.lock.password.length, false); field.refusing = false; } }
    }
    Connections {
        target: field.lock
        function onFailuresChanged() {
            if (field.lock.failures === 0) return;
            refuse.stop(); refuseStill.stop();
            // Before the lock clears the password: the dots stay for the shake.
            field.refusing = true;
            if (Motion.enabled) refuse.restart(); else refuseStill.restart();
        }
        function onLeavingChanged() { if (field.lock.leaving) typingTint.sweep(); }
    }

    // ------------------------------------------------------- the tints ---
    /// Something typed (or being checked, or let in): the field is on.
    readonly property bool lit: (field.lock.password.length > 0 || field.lock.busy || field.lock.leaving) && !field.refusing
    // Gently: paler than a tile that is on, and growing with the first few characters.
    Item {
        anchors.fill: parent
        opacity: field.lock.leaving ? 1 : 0.6 + 0.4 * Math.min(1, field.lock.password.length / 8)
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.emphasized } }
        ShellTint {
            id: typingTint
            anchors.fill: parent
            radius: field.radius
            group: "lock"
            active: field.lit
        }
    }
    // A refusal: the same lit glass with its light in Colors.danger, a light
    // passing across it once, for as long as the flash.
    Item {
        anchors.fill: parent
        opacity: field.flash
        visible: opacity > 0
        ShellTint {
            id: dangerTint
            anchors.fill: parent
            radius: field.radius
            group: "lock"
            tint: Colors.danger
        }
    }

    // ------------------------------------------------- the checking sweep ---
    // Cut to the field's own shape: `clip` only ever cuts square, so the
    // light would run on past the rounded corners as a bright rectangle. The
    // mask is the glass's rounded rectangle (same bounds, same radius).
    Rectangle {
        id: sweepMask
        anchors.fill: parent
        radius: field.radius
        visible: false
        layer.enabled: true
        layer.smooth: true
    }
    Item {
        anchors.fill: parent
        // Fades with the check: a quick answer would cut the light off mid-way.
        opacity: field.lock.busy ? 1 : 0
        Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.fast } }
        visible: opacity > 0 && Motion.enabled
        layer.enabled: visible
        layer.effect: MultiEffect { maskEnabled: true; maskSource: sweepMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Rectangle {
            id: sweep
            width: field.width * 0.45; height: field.height
            property real p: 0
            x: -width + p * (field.width + width)
            // A passing light, white like the one that crosses a piece
            // turning on (Tint): the colour stays under the glass.
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, Colors.dark ? 0.22 : 0.6) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }
            NumberAnimation on p { running: sweep.visible; loops: Animation.Infinite; from: 0; to: 1; duration: Motion.emphasized * 3; easing.type: Easing.InOutQuad }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding * 1.5; anchors.rightMargin: Tokens.padding * 1.2
        spacing: Tokens.gap
        // The colour of a lit piece is in its icon.
        Icon { id: lockIcon; name: "lock"; color: Qt.tint(field.lit ? Colors.accent : Colors.textDim, Colors.alpha(Colors.danger, field.flash)); anchors.verticalCenter: parent.verticalCenter }
        Item {
            width: parent.width - lockIcon.width - caps.width - 2 * Tokens.gap
            height: parent.height
            TextInput {
                id: input
                anchors.fill: parent
                // Typed into, never shown: the dots below are the echo.
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorVisible: false
                cursorDelegate: Item {}
                echoMode: TextInput.Password
                // Marked sensitive for the input method. What keeps an engine away
                // from it is Layouts' hold, for as long as the screen is locked;
                // keymaps stay usable, for a password that is not in Latin.
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                font.pixelSize: Tokens.textLarge
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                enabled: !field.lock.busy && !field.lock.leaving
                onTextChanged: if (field.lock.password !== text) field.lock.password = text
                onAccepted: field.lock.submit()
                Keys.onPressed: event => {
                    field.lock.poke();
                    if (event.key === Qt.Key_CapsLock) field.lock.checkCaps();
                    event.accepted = false;
                }
                Keys.onReleased: event => { if (event.key === Qt.Key_CapsLock) field.lock.checkCaps(); event.accepted = false; }
                Keys.onEscapePressed: text = ""
            }
            // The password is the lock's: typed here, or cleared by it after a failure.
            Connections {
                target: field.lock
                function onPasswordChanged() {
                    if (input.text !== field.lock.password) input.text = field.lock.password;
                    if (!field.refusing) dots.sync(field.lock.password.length, true);
                }
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                opacity: dotModel.count === 0 && !field.refusing ? 1 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim { duration: Motion.standard } }
                // (A check always has dots over it: LockView's line says "Checking…".)
                text: "Password"
                role: "dim"
                size: Tokens.textLarge
            }
            ListView {
                id: dots
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: Tokens.textLarge
                orientation: ListView.Horizontal
                interactive: false
                spacing: Tokens.gap * 0.7
                clip: true
                opacity: field.dotsOpacity
                model: ListModel { id: dotModel }
                property bool animated: true
                /// To n dots; animated: each one grows or shrinks (typing), else all at once.
                function sync(n, anim) {
                    animated = anim;
                    if (!anim && n === 0) dotModel.clear();
                    while (dotModel.count < n) dotModel.append({});
                    while (dotModel.count > n) dotModel.remove(dotModel.count - 1);
                    animated = true;
                    positionViewAtEnd();
                }
                delegate: Rectangle {
                    width: Tokens.textLarge * 0.55; height: width; radius: width / 2
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    color: Qt.tint(Colors.text, Colors.alpha(Colors.danger, field.flash))
                }
                add: Transition {
                    enabled: Motion.enabled && dots.animated
                    NumberAnimation { property: "scale"; from: 0; to: 1; duration: Motion.standard; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.fast }
                }
                remove: Transition {
                    enabled: Motion.enabled && dots.animated
                    NumberAnimation { property: "scale"; to: 0; duration: Motion.fast; easing.type: Easing.InCubic }
                    NumberAnimation { property: "opacity"; to: 0; duration: Motion.fast }
                }
            }
        }
        // Caps Lock: Phosphor's arrow-fat-line-up (⇪), a thin line like every icon here.
        Item {
            id: caps
            readonly property bool on: field.lock.capsLock
            anchors.verticalCenter: parent.verticalCenter
            width: on ? Tokens.iconSize : 0
            height: Tokens.iconSize
            clip: true
            Behavior on width { enabled: Motion.enabled; SpringAnim { token: Motion.snappy } }
            Icon {
                anchors.centerIn: parent
                name: "caps-lock"
                opacity: caps.on ? 0.9 : 0
                Behavior on opacity { enabled: Motion.enabled; EaseAnim {} }
            }
        }
    }
}
