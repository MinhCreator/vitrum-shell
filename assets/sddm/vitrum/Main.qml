import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "lock.js" as Lib
import "motion.js" as M

/*
 * vitrum for SDDM: the lock screen before login. The same picture, the same
 * time cut out of glass, your picture and a greeting, the glass field for the
 * password, the status islands and the power tiles, at the same sizes and with
 * the same motion as shell/modules/lock. What the lock has and a greeter does
 * not need is left out (notifications, the player, the quiet screen); what a
 * greeter needs on top is at the bottom left: the session, and the user when
 * there are several.
 *
 * Lit glass, as in the shell: what is on (a field being typed into, an open
 * list, an armed power tile) is the glass turned frosty with a bright rim; the
 * colour is only a light under the piece and in its icon.
 *
 * One source with the shell wherever a file can be shared: the installer
 * copies Glass.qml (with glass.frag.qsb), Tint.qml, lock.js (the words, the
 * entrance, the refusal's timings), motion.js and the Phosphor Light font
 * beside this file (lib/stages/70-boot.sh). The rest is the lock's QML again,
 * without the shell's singletons: sizes come from `dens` (Tokens), colours
 * from the c* roles (Colors), durations from `motion` (Motion).
 *
 * The picture, your face, the palette, the scheme, the density and the motion
 * settings come from the picked user's /var/lib/vitrum/login/<user>/ (the
 * shell keeps it through vitrum's root helper, which checks every value), else
 * from theme.conf, which the installer writes. Never from a home.
 *
 * SDDM loads this file once per screen. The whole greeter shows where the
 * keyboard is (the focused window; the primary screen until one is); the
 * other screens keep the picture, the time and the date.
 */
Rectangle {
    id: root
    width: 1920; height: 1080
    color: cBg

    // ------------------------------------------------- the user's settings ---
    // palette.json's schemes ({ dark: {…}, light: {…} }) and login.json.
    property var pal: ({})
    property var info: ({})
    /// The typed name has a login folder (typeName only).
    property bool userKnown: false

    // Day or night by the user's sunrise and sunset (or schedule).
    function minutes(hhmm) { const p = String(hhmm || "").split(":"); return (parseInt(p[0], 10) || 0) * 60 + (parseInt(p[1], 10) || 0); }
    readonly property bool isDay: {
        const m = now.getHours() * 60 + now.getMinutes();
        const l = minutes(info.light || "07:00"), d = minutes(info.dark || "19:30");
        return l < d ? (m >= l && m < d) : (m >= l || m < d);
    }
    // The desktop's scheme; "auto" goes by the day. Light only with a light
    // palette to draw it in. Nothing said (an older install): dark, as before.
    readonly property bool wantLight: info.scheme === "light" || (info.scheme === "auto" && isDay)
    readonly property bool dark: !(wantLight && pal.light && typeof pal.light === "object")
    readonly property var roles: (dark ? pal.dark : pal.light) || ({})
    /// A role: the user's palette, else theme.conf (dark only), else the preset.
    function role(name, darkDefault, lightDefault) {
        return roles[name] || (dark ? (config[name] || darkDefault) : lightDefault);
    }
    readonly property color cText: role("text", "#eceef2", "#1b1d21")
    readonly property color cDim: role("textDim", "#a3a8b3", "#5c626b")
    readonly property color cAccent: role("accent", "#8ab4f8", "#1a5fb4")
    readonly property color cDanger: role("danger", "#ef6b6b", "#c8423e")
    readonly property color cBg: role("bg", "#141518", "#f2f3f5")
    /// Glass that is off (LockGlass.rest).
    readonly property color rest: Qt.rgba(1, 1, 1, dark ? 0.07 : 0.16)
    readonly property string fontName: info.font || config.font || "Inter"
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // Sizes: the shell's Tokens at the user's density, times `unit` (the lock
    // at 1080 lines; a taller screen scales everything with it).
    function tokens(density) {
        if (density === "regular") return { island: 34, text: 13, large: 16, title: 24, icon: 18, gap: 10, pad: 12, panel: 22 };
        if (density === "comfortable") return { island: 38, text: 14, large: 17, title: 26, icon: 20, gap: 12, pad: 14, panel: 24 };
        return { island: 30, text: 12, large: 15, title: 22, icon: 16, gap: 8, pad: 10, panel: 20 };
    }
    readonly property var dens: tokens(info.density)
    readonly property real unit: Math.max(1, height / 1080)
    readonly property real textScale: { const v = Number(info.textScale); return v >= 0.85 && v <= 1.3 ? v : 1; }
    readonly property real islandH: dens.island * unit
    readonly property real gap: dens.gap * unit
    readonly property real pad: dens.pad * unit
    readonly property real iconSize: dens.icon * unit
    readonly property real textSize: Math.round(dens.text * textScale) * unit
    readonly property real textLarge: Math.round(dens.large * textScale) * unit
    readonly property real textTitle: Math.round(dens.title * textScale) * unit
    readonly property real rTile: Math.round(12 * dens.panel / 20) * unit
    readonly property real rButton: Math.round(9 * dens.panel / 20) * unit
    readonly property real rIsland: Math.round(10 * dens.panel / 20) * unit
    readonly property real hairline: Math.max(1, Math.round(unit))

    // Motion: the shell's tokens at the user's speed; `still` (reduced motion,
    // lite mode) makes every duration 0 and switches the Behaviors off.
    readonly property real speed: { const v = Number(info.speed); return v >= 0.1 && v <= 4 ? v : 1; }
    readonly property bool still: info.still === true
    QtObject {
        id: motion
        readonly property bool enabled: !root.still
        readonly property int fast: M.scaled(150, root.speed, root.still)
        readonly property int standard: M.scaled(240, root.speed, root.still)
        readonly property int emphasized: M.scaled(380, root.speed, root.still)
        readonly property int colour: M.scaled(300, root.speed, root.still)
        readonly property int drift: M.scaled(M.DRIFT_MS, root.speed, root.still)
        readonly property int sweep: M.scaled(M.SWEEP_MS, root.speed, root.still)
        readonly property int enter: Math.round(emphasized * 2.2)
        readonly property int leave: Math.round(emphasized * 1.6)
        readonly property var snappy: M.spring("snappy", root.speed)
        readonly property var smooth: M.spring("smooth", root.speed)
        /// A wrong password's timings (never 0: it must be seen).
        readonly property var refusal: Lib.refusal(root.speed)
    }

    // Line icons: Phosphor Light, the shell's names (shell/data/icons.json;
    // tests/sh/test_boot.sh keeps the two in step). Without the font file the
    // tiles show their words instead.
    FontLoader { id: iconFont; source: Qt.resolvedUrl("Phosphor-Light.ttf") }
    readonly property bool iconsReady: iconFont.status === FontLoader.Ready
    readonly property var glyphs: ({
        "lock": "\ue2fa", "caps-lock": "\ue522", "keyboard": "\ue2d8", "battery": "\ue0c0", "bolt": "\ue2de",
        "user": "\ue4c2", "desktop": "\ue560", "check": "\ue182", "power": "\ue3da", "restart": "\ue038", "sleep": "\ue330"
    })

    // ------------------------------------------------------ users, sessions ---
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    // The remembered session; on a first login (no last user) vitrum, if it is installed.
    property int sessionIndex: {
        // The remembered one only while it still exists.
        if (userModel.lastUser && sessionModel.lastIndex >= 0) return sessionModel.lastIndex;
        for (let i = 0; i < sessionModel.rowCount(); i++)
            if (String(sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 2)).endsWith("/vitrum.desktop")) return i;
        return Math.max(0, sessionModel.lastIndex);
    }
    // No users listed (LDAP, SSSD, or outside SDDM's UID range): a name field instead.
    readonly property bool typeName: userModel.count === 0
    /// The name in that field, once the typing pauses.
    property string typedName: ""
    Timer { id: nameLater; interval: 350; onTriggered: root.typedName = nameField.text.trim() }
    property string error: ""
    /// What PAM said during this attempt (a locked account, an expired password).
    property string pamNote: ""
    property bool busy: false
    property bool leaving: false

    function userName(i) { return userModel.data(userModel.index(i, 0), Qt.UserRole + 1) || ""; }
    function realName(i) { return userModel.data(userModel.index(i, 0), Qt.UserRole + 2) || ""; }
    function userIcon(i) { return userModel.data(userModel.index(i, 0), Qt.UserRole + 4) || ""; }
    function needsPassword(i) { return typeName || userModel.data(userModel.index(i, 0), Qt.UserRole + 5) !== false; }
    function sessionName(i) { return sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 4) || ""; }
    readonly property string loginName: typeName ? nameField.text.trim() : userName(userIndex)
    readonly property var userNames: {
        const out = [];
        for (let i = 0; i < userModel.count; i++) out.push(String(realName(i) || userName(i)));
        return out;
    }
    readonly property var sessionNames: {
        const out = [];
        for (let i = 0; i < sessionModel.rowCount(); i++) out.push(String(sessionName(i)));
        return out;
    }

    // The user on show: switching fades the old picture and name out, then the new in.
    property int shownUser: 0
    property real swap: 1
    SequentialAnimation {
        id: swapAnim
        NumberAnimation { target: root; property: "swap"; to: 0; duration: motion.fast; easing.type: Easing.InCubic }
        ScriptAction { script: root.shownUser = root.userIndex }
        NumberAnimation { target: root; property: "swap"; to: 1; duration: motion.standard; easing.type: Easing.OutCubic }
    }
    onUserIndexChanged: {
        // (Before the entrance: SDDM's remembered user settling in, not a switch.)
        if (!begun || !motion.enabled) { shownUser = userIndex; return; }
        password.text = ""; error = "";
        swapAnim.restart();
    }
    /// What the greeting calls you. A typed name: only once it is known here.
    readonly property string shownName: typeName ? (userKnown ? Lib.firstName("", typedName) : "")
                                                 : Lib.firstName(realName(shownUser), userName(shownUser))

    function focusField() {
        openPicker = null;
        (typeName && !nameField.text ? nameField : password).forceActiveFocus();
    }
    function login() {
        const name = loginName;
        if (busy || leaving || !full || !name || (!password.text && needsPassword(userIndex))) return;
        busy = true; error = ""; pamNote = "";
        sddm.login(name, password.text, sessionIndex);
    }

    Connections {
        target: sddm
        function onInformationMessage(message) {
            if (!root.busy) return;
            const m = String(message || "").replace(/\s+/g, " ").trim();
            // PAM's plain "Authentication failure" says less than "Wrong password".
            root.pamNote = /^authentication fail/i.test(m) ? "" : m.slice(0, 80);
        }
        function onLoginFailed() {
            if (!root.busy) return;   // another screen's attempt
            root.busy = false;
            root.error = root.pamNote || "Wrong password";
            // First: the field holds its dots for the shake once it is refusing.
            field.refuse();
            password.text = "";
            root.focusField();
        }
        function onLoginSucceeded() { root.busy = false; root.leaving = true; }
    }

    // ------------------------------------------------ the user's login folder ---
    // What the shell left, checked and copied by vitrum's root helper (never
    // read from the user's home). Files are read with XMLHttpRequest
    // (QML_XHR_ALLOW_FILE_READ, set by the installer).
    /// A name that is safe in a path (the helper's own rule), else "".
    function safeName(n) { return /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,31}$/.test(String(n || "")) ? String(n) : ""; }
    function dirFor(name) { const n = safeName(name); return n ? "/var/lib/vitrum/login/" + n : ""; }
    readonly property string loginDir: dirFor(typeName ? typedName : userName(userIndex))
    function readText(path, done) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) done(String(x.responseText || "")); };
        try { x.open("GET", "file://" + path); x.send(); } catch (e) { done(""); }
    }
    function readJson(path, done) {
        readText(path, t => {
            let v = null;
            try { v = JSON.parse(t); } catch (e) { v = null; }
            done(v !== null && typeof v === "object" ? v : null);
        });
    }
    function loadUser() {
        const dir = loginDir;
        if (!dir) { pal = ({}); info = ({}); userKnown = false; begin(); return; }
        let left = 2;
        const done = () => { if (--left === 0) root.begin(); };
        readJson(dir + "/login.json", v => {
            if (dir === root.loginDir) { root.info = v || ({}); root.userKnown = v !== null; }
            done();
        });
        readJson(dir + "/palette.json", v => {
            if (dir === root.loginDir) root.pal = (v && v.palette && typeof v.palette === "object") ? v.palette : ({});
            done();
        });
    }
    onLoginDirChanged: loadUser()
    readonly property string userWallpaper: loginDir ? "file://" + loginDir + "/" + (isDay ? "day" : "night") : ""
    /// The folder with the shown user's picture.
    readonly property string faceDir: typeName ? (userKnown ? loginDir : "") : dirFor(userName(shownUser))
    /// SDDM's own picture for the user; its stock silhouette counts as none.
    readonly property string sddmFace: {
        const p = typeName ? "" : String(userIcon(shownUser) || "");
        return p.indexOf("/faces/.face.icon") >= 0 ? "" : p;
    }

    // The battery, straight from the kernel (no shell here to ask): the first
    // one that answers. Nothing on a desktop.
    property int battery: -1
    property bool charging: false
    function loadBattery(names) {
        if (!names.length) { battery = -1; return; }
        const dir = "/sys/class/power_supply/" + names[0];
        readText(dir + "/capacity", t => {
            const n = parseInt(t, 10);
            if (!(n >= 0 && n <= 100)) { root.loadBattery(names.slice(1)); return; }
            root.battery = n;
            root.readText(dir + "/status", s => { root.charging = s.trim() === "Charging"; });
        });
    }
    Timer { interval: 60000; running: root.full; repeat: true; triggeredOnStart: true; onTriggered: root.loadBattery(["BAT0", "BAT1", "BAT2", "BATT"]) }

    // --------------------------------------------------------- choreography ---
    // As the lock's (LockView): `enter` 0 → 1 brings the blocks in one after
    // another, `leave` 0 → 1 after a good password lets them float off while
    // the picture sharpens and a light blooms out of the field.
    property real enter: 0
    NumberAnimation { id: enterAnim; target: root; property: "enter"; from: 0; to: 1; duration: motion.enabled ? motion.enter : 0; easing.type: Easing.Linear }
    // The entrance waits for the user's settings (a moment), so it starts in
    // their scheme and at their speed instead of changing on the way.
    property bool begun: false
    function begin() { if (begun) return; begun = true; enterAnim.start(); }
    Timer { interval: 300; running: true; onTriggered: root.begin() }

    property real leave: leaving ? 1 : 0
    Behavior on leave { enabled: motion.enabled; NumberAnimation { duration: motion.leave; easing.type: Easing.InOutCubic } }

    /// The highest `order` of the entrance (the tiles at the bottom), as the lock's.
    readonly property int lastOrder: 8
    function rise(order) { return Lib.rise(root.enter, order, root.lastOrder); }

    // Which screen has the whole greeter: the one with the keyboard. Before
    // any window has it, the primary one. A single screen always has it.
    readonly property bool isPrimary: typeof primaryScreen === "undefined" || primaryScreen !== false
    readonly property bool alone: !(Qt.application.screens.length > 1)
    readonly property bool full: alone || root.Window.active === true || (Qt.application.state !== Qt.ApplicationActive && isPrimary)
    property real shown: full ? 1 : 0
    Behavior on shown { enabled: motion.enabled; NumberAnimation { duration: motion.standard; easing.type: Easing.OutCubic } }
    // (Later: the fields are enabled by the same change, and must be first.)
    onFullChanged: { if (full) Qt.callLater(focusField); else openPicker = null; }
    /// How much of a block that is not the time or the date shows.
    readonly property real chrome: Lib.chrome(0, leave) * shown

    // SDDM closes this window the moment the login succeeds, before anything
    // here could move. The window that sent the password asks for the length
    // of the leave, once, then closes itself; any later close (the greeter
    // being stopped) goes through untouched.
    property bool held: false
    Connections {
        target: root.Window.window
        ignoreUnknownSignals: true
        function onClosing(close) {
            if (root.held || !motion.enabled || !(root.busy || root.leaving)) return;
            root.held = true;
            close.accepted = false;
            closeLater.start();
        }
    }
    Timer {
        id: closeLater
        interval: motion.leave + 60
        onTriggered: { const w = root.Window.window; if (w) w.close(); }
    }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

    // ------------------------------------------------------------ wallpaper ---
    // The user's own picture when there is one, else the installer's.
    Image { id: userWall; source: root.userWallpaper; asynchronous: true; visible: false }
    readonly property string wallSource: userWall.status === Image.Ready ? root.userWallpaper : (config.background || "")
    // Settles from 1.1 to 1.04 (blurred edges pull in transparency), and to
    // 1 on the way out: the last frame is the plain picture the desktop starts on.
    readonly property real wallScale: 1 + (0.1 - 0.06 * Math.min(1, root.enter * 1.3)) * (1 - root.leave)

    // What the glass looks through: the wallpaper, blurred, and the dim on it.
    Item {
        id: wallBackdrop
        anchors.fill: parent
        Image {
            id: wall
            anchors.fill: parent
            source: root.wallSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wall
            visible: wall.status === Image.Ready
            blurEnabled: true
            blurMax: 64
            // Blurs in, and sharpens again on the way to the session.
            blur: Math.min(1, root.enter * 1.4) * 0.85 * (1 - root.leave)
            scale: root.wallScale
            opacity: Math.min(1, root.enter * 3)
        }
        // No picture at all: a quiet fall from the accent to the background.
        Rectangle {
            anchors.fill: parent
            visible: wall.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: root.dark ? Qt.darker(root.cAccent, 3.2) : Qt.lighter(root.cAccent, 1.6) }
                GradientStop { position: 1; color: root.cBg }
            }
        }
        Rectangle { anchors.fill: parent; color: root.cBg; opacity: Number(config.dim || 0.32) * Math.min(1, root.enter * 2) * (1 - root.leave) }
    }
    // One texture of it for every piece of glass.
    ShaderEffectSource { id: backdropTex; sourceItem: wallBackdrop; visible: false; hideSource: false }
    // The clock is clear glass: sharp through the digits, blurred around them.
    Item {
        id: clearBackdrop
        anchors.fill: parent
        visible: false
        Image {
            anchors.fill: parent
            source: root.wallSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            scale: root.wallScale
        }
        Rectangle { anchors.fill: parent; color: root.cBg; opacity: 0.12 }
    }
    ShaderEffectSource { id: clearTex; sourceItem: clearBackdrop; visible: false; hideSource: false }

    // --------------------------------------------------------------- centre ---
    Column {
        id: centre
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.04
        spacing: root.gap * 2
        enabled: root.full && !root.leaving
        // Floats up a little on the way to the session.
        transform: Translate { y: -root.leave * root.islandH }

        // The time, cut out of glass: the wallpaper bends through the digits.
        Rise {
            order: 0
            keep: true
            anchors.horizontalCenter: parent.horizontalCenter
            width: clockGlass.width; height: clockGlass.height
            Glass {
                id: clockGlass
                width: clock.width; height: clock.height
                backdrop: clearBackdrop
                source: clearTex
                bevel: clock.size * 0.08
                refraction: clock.size * 0.22
                edgeLight: 0.8
                fringing: 0.35
                saturation: 1.25
                brightness: 0.06
                tint: Qt.rgba(1, 1, 1, root.dark ? 0.05 : 0.12)
                shadow: 0.4
                RollClock {
                    id: clock
                    time: Qt.formatTime(root.now, root.info.h24 === false ? "h:mm" : "HH:mm")
                    size: Math.round(root.height * 0.17)
                }
            }
        }
        // The date, just under the time.
        Rise {
            order: 1
            keep: true
            anchors.horizontalCenter: parent.horizontalCenter
            width: today.width; height: today.height
            // Pulled up to the digits: the Column's spacing is for the blocks.
            shiftY: -root.gap * 1.8
            Label { id: today; text: Qt.formatDate(root.now, "dddd, d MMMM"); size: root.textLarge * 1.15; font.weight: Font.DemiBold }
        }
        // (The date sits pulled up: this gap and the spacing make up the room under it.)
        Item { width: 1; height: 1 }

        // You: your picture (the one the shell left, else SDDM's), or your
        // initial, on a round disc of glass inside a rim of lit glass:
        // frosted, a bright hairline, the accent only as a soft light under it.
        Rise {
            order: 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.islandH * 3; height: width
            opacity: root.rise(order) * root.chrome * root.swap
            scale: 0.9 + 0.1 * root.swap
            Item {
                id: avatar
                anchors.fill: parent
                /// From the rim to the disc: the band of lit glass round it.
                readonly property real band: Math.max(4 * root.unit, root.islandH * 0.18)
                readonly property bool hasPicture: face.status === Image.Ready

                Lit { anchors.fill: parent; radius: width / 2 }
                Rectangle {
                    id: disc
                    anchors.fill: parent
                    anchors.margins: avatar.band
                    radius: width / 2
                    color: root.rest
                    Label {
                        anchors.centerIn: parent
                        visible: !avatar.hasPicture
                        text: Lib.initial(root.shownName)
                        size: root.textTitle * 1.4
                        font.weight: Font.DemiBold
                    }
                    Image {
                        id: face
                        anchors.fill: parent
                        /// The folder the shell left no picture in: SDDM's instead.
                        property string without: ""
                        readonly property bool own: root.faceDir !== "" && root.faceDir !== without
                        source: own ? "file://" + root.faceDir + "/face" : root.sddmFace
                        // (face.status: a bare `status` here is the line under the field, by its id.)
                        onStatusChanged: if (face.status === Image.Error && face.own) face.without = root.faceDir
                        asynchronous: true
                        sourceSize.width: width * 2; sourceSize.height: height * 2
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: face
                        source: face
                        visible: avatar.hasPicture
                        maskEnabled: true
                        maskSource: faceMask
                    }
                    Item {
                        id: faceMask
                        anchors.fill: face
                        layer.enabled: true
                        visible: false
                        Rectangle { anchors.fill: parent; radius: width / 2 }
                    }
                    // The glass rim, over the picture too.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: root.hairline
                        border.color: Qt.rgba(1, 1, 1, root.dark ? 0.32 : 0.6)
                    }
                }
            }
        }
        Rise {
            order: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: hello.width; height: hello.height
            opacity: root.rise(order) * root.chrome * root.swap
            // Close under the picture: one group with it, apart from the field.
            shiftY: -root.gap * 0.9
            Label { id: hello; text: Lib.greeting(root.now.getHours(), root.shownName); size: root.textLarge; font.weight: Font.Medium; font.letterSpacing: 0.2 }
        }

        // No list of users: the name is typed, in a field like the password's.
        Rise {
            order: 4
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.typeName
            width: field.width; height: field.height
            GlassPane {
                anchors.fill: parent
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: root.pad * 1.5; anchors.rightMargin: root.pad * 1.2
                    spacing: root.gap
                    Item {
                        id: nameSlot
                        width: root.iconsReady ? root.iconSize : 0; height: parent.height
                        Icon { anchors.centerIn: parent; name: "user"; color: root.cDim }
                    }
                    TextInput {
                        id: nameField
                        width: parent.width - nameSlot.width - root.gap; height: parent.height
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.cText
                        selectionColor: root.alpha(root.cAccent, 0.4)
                        selectedTextColor: root.cText
                        clip: true
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        font.family: root.fontName
                        font.pixelSize: root.textLarge
                        KeyNavigation.tab: password
                        onAccepted: password.forceActiveFocus()
                        onTextChanged: { root.error = ""; nameLater.restart(); }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !nameField.text
                            text: "User name"
                            dim: true
                            size: root.textLarge
                        }
                    }
                }
            }
        }

        // The password field, of glass (LockField). The text itself is never
        // drawn: each character is a dot that grows in and shrinks away when
        // erased. Typed into, it turns on (lit glass, the accent in its lock
        // icon); while SDDM checks, a white light sweeps along it.
        Rise {
            order: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: field.width; height: field.height
            GlassPane {
                id: field
                width: root.islandH * 11
                height: root.islandH * 1.4
                outline: Qt.tint(root.alpha(root.cText, 0.12), root.alpha(root.cDanger, 0.85 * flash))
                edgeLight: 0.5 + 0.3 * flash

                // A wrong password: the glass lights up in the danger colour,
                // the dots blush red and the field shakes — one damped swing —
                // then the dots go out together and the hint fades back in.
                // The timings are the lock's (Lib.refusal), at the motion
                // speed. With animations off: the red light comes on, holds
                // and goes.
                property real flash: 0
                property real swing: 0            // 0 → 1 over the shake
                property bool refusing: false
                property real dotsOpacity: 1
                readonly property var t: motion.refusal
                readonly property real shake: root.islandH * 0.42 * Math.sin(swing * Math.PI * 6) * Math.pow(1 - swing, 2)
                transform: Translate { x: field.shake }

                function refuse() {
                    refuseAnim.stop(); refuseStill.stop();
                    refusing = true;
                    if (motion.enabled) refuseAnim.restart(); else refuseStill.restart();
                }
                SequentialAnimation {
                    id: refuseAnim
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
                    // The dots go while they are invisible: the ListView runs its
                    // remove transition after sync() returns, so lighting them
                    // first showed the old dots shrinking over the hint.
                    ScriptAction { script: dots.sync(password.text.length, false) }
                    PauseAnimation { duration: motion.fast + 40 }
                    ScriptAction { script: { dots.sync(password.text.length, false); field.refusing = false; field.dotsOpacity = 1; } }
                }
                // Animations off: no swing and no fades, but a refusal must still be seen.
                SequentialAnimation {
                    id: refuseStill
                    ScriptAction { script: { field.swing = 0; field.dotsOpacity = 1; field.flash = 1; } }
                    PauseAnimation { duration: field.t.flashIn + field.t.hold }
                    ScriptAction { script: { field.flash = 0; dots.sync(password.text.length, false); field.refusing = false; } }
                }
                Connections { target: root; function onLeavingChanged() { if (root.leaving) typingTint.sweep(); } }

                /// Something typed (or being checked, or let in): the field is on.
                readonly property bool lit: (password.text.length > 0 || root.busy || root.leaving) && !field.refusing
                // Gently: paler than a tile that is on, and growing with the first few characters.
                Item {
                    anchors.fill: parent
                    opacity: root.leaving ? 1 : 0.6 + 0.4 * Math.min(1, password.text.length / 8)
                    Behavior on opacity { enabled: motion.enabled; NumberAnimation { duration: motion.emphasized; easing.type: Easing.OutCubic } }
                    Lit { id: typingTint; anchors.fill: parent; radius: field.radius; active: field.lit }
                }
                // A refusal: the same lit glass with its light in the danger
                // colour, a light passing across it once, as long as the flash.
                Item {
                    anchors.fill: parent
                    opacity: field.flash
                    visible: opacity > 0
                    Lit { id: dangerTint; anchors.fill: parent; radius: field.radius; tint: root.cDanger }
                }

                // The checking sweep, cut to the field's own shape: `clip` only
                // ever cuts square, so the light would run on past the rounded
                // corners as a bright rectangle. The mask is the glass's
                // rounded rectangle (same bounds, same radius).
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
                    opacity: root.busy ? 1 : 0
                    Behavior on opacity { enabled: motion.enabled; NumberAnimation { duration: motion.fast; easing.type: Easing.OutCubic } }
                    visible: opacity > 0 && motion.enabled
                    layer.enabled: visible
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: sweepMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                    Rectangle {
                        id: sweep
                        width: field.width * 0.45; height: field.height
                        property real p: 0
                        x: -width + p * (field.width + width)
                        // A passing light, white like the one that crosses a
                        // piece turning on (Tint): the colour stays under the glass.
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, root.dark ? 0.22 : 0.6) }
                            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                        }
                        NumberAnimation on p { running: sweep.visible; loops: Animation.Infinite; from: 0; to: 1; duration: Math.max(1, motion.emphasized * 3); easing.type: Easing.InOutQuad }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: root.pad * 1.5; anchors.rightMargin: root.pad * 1.2
                    spacing: root.gap
                    Item {
                        id: lockSlot
                        width: root.iconsReady ? root.iconSize : 0; height: parent.height
                        // The colour of a lit piece is in its icon.
                        Icon { anchors.centerIn: parent; name: "lock"; color: Qt.tint(field.lit ? root.cAccent : root.cDim, root.alpha(root.cDanger, field.flash)) }
                    }
                    Item {
                        width: parent.width - lockSlot.width - caps.width - 2 * root.gap
                        height: parent.height
                        TextInput {
                            id: password
                            anchors.fill: parent
                            // Typed into, never shown: the dots below are the echo.
                            color: "transparent"
                            selectionColor: "transparent"
                            selectedTextColor: "transparent"
                            cursorVisible: false
                            cursorDelegate: Item {}
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            font.pixelSize: root.textLarge
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            focus: true
                            enabled: !root.busy && !root.leaving
                            onAccepted: root.login()
                            // Typing again answers the error: it has been read.
                            onTextChanged: { if (text) root.error = ""; if (!field.refusing) dots.sync(text.length, true); }
                            Keys.onEscapePressed: text = ""
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: dotModel.count === 0 && !field.refusing ? 1 : 0
                            Behavior on opacity { enabled: motion.enabled; NumberAnimation { duration: motion.standard; easing.type: Easing.OutCubic } }
                            text: root.needsPassword(root.userIndex) ? "Password" : "Press Enter to sign in"
                            dim: true
                            size: root.textLarge
                        }
                        ListView {
                            id: dots
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: root.textLarge
                            orientation: ListView.Horizontal
                            interactive: false
                            spacing: root.gap * 0.7
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
                                width: root.textLarge * 0.55; height: width; radius: width / 2
                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                color: Qt.tint(root.cText, root.alpha(root.cDanger, field.flash))
                            }
                            add: Transition {
                                enabled: motion.enabled && dots.animated
                                NumberAnimation { property: "scale"; from: 0; to: 1; duration: motion.standard; easing.type: Easing.OutCubic }
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: motion.fast }
                            }
                            remove: Transition {
                                enabled: motion.enabled && dots.animated
                                NumberAnimation { property: "scale"; to: 0; duration: motion.fast; easing.type: Easing.InCubic }
                                NumberAnimation { property: "opacity"; to: 0; duration: motion.fast }
                            }
                        }
                    }
                    // Caps Lock: a small line icon at the right end (without
                    // the icon font the line under the field says it).
                    Item {
                        id: caps
                        readonly property bool on: keyboard.capsLock === true && root.iconsReady
                        anchors.verticalCenter: parent.verticalCenter
                        width: on ? root.iconSize : 0
                        height: root.iconSize
                        clip: true
                        Behavior on width { enabled: motion.enabled; Spring { token: motion.snappy } }
                        Icon {
                            anchors.centerIn: parent
                            name: "caps-lock"
                            opacity: caps.on ? 0.9 : 0
                            Behavior on opacity { enabled: motion.enabled; NumberAnimation { duration: motion.standard; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
        Rise {
            order: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: status.width; height: status.height
            // One line: what went wrong, the check, or a word about Caps Lock.
            // A new one fades in after the old one is out; a check quicker
            // than that never shows its word.
            Label {
                id: status
                readonly property string want: Lib.statusLine(root.error, root.busy, keyboard.capsLock === true)
                property bool bad: false
                function take() { text = want; bad = root.error.length > 0; }
                text: " "
                color: bad ? root.cDanger : root.cDim
                Component.onCompleted: take()
                onWantChanged: {
                    if (motion.enabled) statusSwap.restart();
                    else { statusSwap.stop(); take(); opacity = 1; }
                }
                SequentialAnimation {
                    id: statusSwap
                    NumberAnimation { target: status; property: "opacity"; to: 0; duration: motion.fast; easing.type: Easing.InCubic }
                    ScriptAction { script: status.take() }
                    NumberAnimation { target: status; property: "opacity"; to: 1; duration: motion.standard; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // A click anywhere else closes an open list.
    property Item openPicker: null
    MouseArea {
        anchors.fill: parent
        enabled: root.openPicker !== null
        onClicked: root.focusField()
    }

    // ----------------------------------------------------- status and power ---
    // Small matching glass islands, as the lock's row: the battery (if any)
    // and the keyboard layout (a click switches it: typing the password in
    // the wrong layout is the classic trap).
    Row {
        id: statusRow
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: root.islandH * 1.5 }
        spacing: root.gap * 0.75
        enabled: root.full && !root.leaving
        opacity: root.rise(7) * root.chrome
        transform: Translate { y: (1 - root.rise(7)) * root.islandH }
        StatusIsland {
            visible: root.battery >= 0
            icon: root.charging ? "bolt" : "battery"
            text: root.battery + "%"
        }
        StatusIsland {
            readonly property var layout: keyboard.layouts.length > 0 ? keyboard.layouts[keyboard.currentLayout] : null
            visible: text.length > 0
            icon: "keyboard"
            text: layout ? String(layout.shortName || "").toUpperCase() : ""
            clickable: keyboard.layouts.length > 1
            onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
    }
    Label {
        anchors { right: parent.right; top: parent.top; margins: root.islandH }
        text: sddm.hostName
        dim: true
        opacity: root.rise(7) * root.chrome
    }

    // The session, and the user when there are several: a tile each, opening
    // a small list. Tab reaches them; Enter or Space opens, the arrows move,
    // Enter picks, Escape goes back to the password.
    Row {
        anchors { left: parent.left; bottom: parent.bottom; margins: root.islandH * 1.5 }
        spacing: root.gap
        enabled: root.full && !root.leaving
        opacity: root.rise(8) * root.chrome
        Picker {
            visible: root.userNames.length > 1
            icon: "user"
            names: root.userNames
            current: root.userIndex
            onPicked: index => root.userIndex = index
        }
        Picker {
            visible: root.sessionNames.length > 0
            icon: "desktop"
            names: root.sessionNames
            current: root.sessionIndex
            onPicked: index => root.sessionIndex = index
        }
    }

    // Sleep, restart, power off: square glass tiles with a line icon each
    // (LockPower). Under the pointer a tile lifts and its name grows out of
    // it. Sleep acts at once; restart and power off need a second press
    // within three seconds: the first one arms the tile — it lights up, its
    // light and its icon in the danger colour, and says to press again.
    property var pending: null
    readonly property int powerWindow: 3000
    Timer { id: disarm; interval: root.powerWindow; onTriggered: root.pending = null }
    function can(action) { return action === "suspend" ? sddm.canSuspend : action === "reboot" ? sddm.canReboot : sddm.canPowerOff; }
    function power(action) {
        const r = Lib.powerPress(pending, action, Date.now(), powerWindow);
        pending = r.pending;
        if (pending) disarm.restart();
        if (r.fire === "suspend") sddm.suspend();
        else if (r.fire === "reboot") sddm.reboot();
        else if (r.fire === "poweroff") sddm.powerOff();
    }
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: root.islandH * 1.5 }
        spacing: root.gap
        layoutDirection: Qt.RightToLeft    // anchored at the right: names grow leftwards
        enabled: root.full && !root.leaving
        opacity: root.rise(8) * root.chrome
        Repeater {
            // Right to left: power off sits in the corner.
            model: [
                { action: "poweroff", icon: "power" },
                { action: "reboot",   icon: "restart" },
                { action: "suspend",  icon: "sleep" }
            ]
            delegate: Tile {
                id: btn
                required property var modelData
                readonly property bool armed: root.pending !== null && root.pending.action === modelData.action
                visible: root.can(modelData.action) === true
                icon: modelData.icon
                text: Lib.powerLabel(modelData.action, armed)
                lit: armed
                light: root.cDanger
                onClicked: root.power(modelData.action)
            }
        }
    }

    // ---------------------------------------------------------- the way out ---
    // A good password: a soft light in the accent, one hue, blooms out of the
    // field as the blocks float off, and fades with them. Drawn only while
    // leaving; with animations off `leave` jumps and it never shows.
    property point flashAt: Qt.point(width / 2, height / 2)
    onLeavingChanged: if (leaving) flashAt = field.mapToItem(root, field.width / 2, field.height / 2)
    Shape {
        id: bloom
        anchors.fill: parent
        readonly property real k: Math.sin(Math.PI * Math.max(0, Math.min(1, root.leave)))
        visible: k > 0.001
        opacity: k * 0.6
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: root.flashAt.x; centerY: root.flashAt.y
                focalX: centerX; focalY: centerY
                centerRadius: Math.max(root.width, root.height) * (0.2 + 0.7 * root.leave)
                focalRadius: 0
                GradientStop { position: 0; color: root.alpha(root.cAccent, 0.55) }
                GradientStop { position: 0.4; color: root.alpha(root.cAccent, 0.3) }
                GradientStop { position: 1; color: root.alpha(root.cAccent, 0) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // -------------------------------------------------------------- pieces ---
    /// A block that rises in with the entrance; `keep` (the time, the date)
    /// stays on every screen.
    component Rise: Item {
        property int order: 0
        property bool keep: false
        property real shiftY: 0
        opacity: root.rise(order) * (keep ? 1 - root.leave : root.chrome)
        transform: Translate { y: (1 - root.rise(order)) * root.islandH * 0.9 + shiftY }
    }

    /// Text in the vitrum type.
    component Label: Text {
        property real size: root.textSize
        property bool dim: false
        color: dim ? root.cDim : root.cText
        font.family: root.fontName
        font.pixelSize: size
        verticalAlignment: Text.AlignVCenter
    }

    /// A line icon by the shell's name for it. Nothing without the icon font.
    component Icon: Text {
        property string name: ""
        property real size: root.iconSize
        visible: root.iconsReady
        text: root.glyphs[name] || ""
        font.family: iconFont.name
        font.pixelSize: size
        color: root.cText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        width: size; height: size
    }

    /// A spring with a motion token (SpringAnim): critically damped, no bounce.
    component Spring: SpringAnimation {
        property var token: motion.smooth
        spring: token.spring
        damping: token.damping
        mass: token.mass
        epsilon: 0.25
    }

    /// Lit glass (Tint) in this theme's colours and motion (ShellTint).
    component Lit: Tint {
        /// The light's colour (danger for an armed tile).
        property color tint: root.cAccent
        color: tint
        color2: tint
        dark: root.dark
        animate: motion.enabled
        duration: motion.drift
        sweepDuration: motion.sweep
        fadeDuration: motion.emphasized
    }

    /// A pane of glass over the blurred wallpaper (LockGlass); children sit on top.
    component GlassPane: Item {
        id: pane
        property real radius: root.rTile
        property color tint: root.rest
        property real edgeLight: 0.5
        property color outline: root.alpha(root.cText, 0.12)
        Glass {
            anchors.fill: parent
            backdrop: wallBackdrop
            source: backdropTex
            bevel: Math.min(18 * root.unit, pane.height * 0.35)
            refraction: Math.min(26 * root.unit, pane.height * 0.45)
            edgeLight: pane.edgeLight
            tint: pane.tint
            Rectangle { anchors.fill: parent; radius: pane.radius }
        }
        Rectangle { anchors.fill: parent; radius: pane.radius; color: "transparent"; border.width: root.hairline; border.color: pane.outline }
    }

    /// One island of the status row: a line icon and a few words on glass;
    /// `clickable` lifts under the pointer.
    component StatusIsland: GlassPane {
        id: isle
        property string icon: ""
        property string text: ""
        property bool clickable: false
        signal clicked()
        height: root.islandH
        radius: root.rIsland
        width: isleRow.implicitWidth + 2 * root.pad
        tint: clickable && isleMouse.containsMouse ? root.alpha(root.cText, isleMouse.pressed ? 0.18 : 0.13) : root.rest
        Behavior on tint { enabled: motion.enabled; ColorAnimation { duration: motion.colour; easing.type: Easing.InOutQuad } }
        Row {
            id: isleRow
            anchors.centerIn: parent
            spacing: root.gap * 0.7
            Icon { name: isle.icon; anchors.verticalCenter: parent.verticalCenter }
            Label { text: isle.text; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
            id: isleMouse
            anchors.fill: parent
            enabled: isle.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: isle.clicked()
        }
    }

    /// A glass tile with a line icon; its name grows out of it under the
    /// pointer or the keyboard focus (always with `expand`, and when there is
    /// no icon font). `lit`: on — lit glass, `light` under it and in its icon.
    component Tile: GlassPane {
        id: tile
        property string icon: ""
        property string text: ""
        property bool lit: false
        property color light: root.cAccent
        property bool expand: false
        /// True while clicked() comes from the keyboard.
        property bool keyed: false
        signal clicked()
        readonly property bool hot: tileMouse.containsMouse || activeFocus
        readonly property bool open: expand || lit || hot || !root.iconsReady
        height: root.islandH * 1.4
        width: root.iconsReady ? height + (open ? tileLabel.implicitWidth + root.pad : 0) : tileLabel.implicitWidth + root.pad * 2.4
        tint: tileMouse.pressed ? root.alpha(root.cText, 0.20) : hot ? root.alpha(root.cText, 0.13) : root.rest
        edgeLight: hot ? 0.75 : 0.5
        Behavior on width { enabled: motion.enabled; Spring { token: motion.smooth } }
        Behavior on tint { enabled: motion.enabled; ColorAnimation { duration: motion.colour; easing.type: Easing.InOutQuad } }
        Behavior on edgeLight { enabled: motion.enabled; NumberAnimation { duration: motion.standard; easing.type: Easing.OutCubic } }
        scale: tileMouse.pressed ? 0.97 : 1
        Behavior on scale { enabled: motion.enabled; Spring { token: motion.snappy } }
        Lit { anchors.fill: parent; radius: tile.radius; tint: tile.light; active: tile.lit; hovered: tile.hot }
        // Only the name is cut as the tile grows: the light under it is not.
        Item {
            anchors.fill: parent
            clip: true
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: root.iconsReady ? (tile.height - root.iconSize) / 2 : root.pad * 1.2
                spacing: root.gap
                Icon { name: tile.icon; color: tile.lit ? tile.light : root.cText; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    id: tileLabel
                    text: tile.text
                    font.weight: tile.lit ? Font.DemiBold : Font.Medium
                    opacity: tile.open ? 1 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on opacity { enabled: motion.enabled; NumberAnimation { duration: motion.standard; easing.type: Easing.OutCubic } }
                }
            }
        }
        activeFocusOnTab: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                tile.keyed = true; tile.clicked(); tile.keyed = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.focusField();
                event.accepted = true;
            }
        }
        MouseArea { id: tileMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.clicked() }
    }

    /// A tile that names the current choice and opens a small glass list of
    /// all of them above itself. One list is open at a time (root.openPicker).
    component Picker: Item {
        id: pick
        property string icon: ""
        property var names: []
        property int current: 0
        signal picked(int index)
        readonly property bool open: root.openPicker === pick
        /// The row the arrows or the pointer are on.
        property int cursor: 0
        /// The widest name, for the list's width.
        property real widest: 0
        width: pickTile.width; height: pickTile.height

        function show() { cursor = current; root.openPicker = pick; pickTile.forceActiveFocus(); }
        function choose(i) {
            root.focusField();
            if (i !== current && i >= 0 && i < names.length) picked(i);
        }
        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Up && event.key !== Qt.Key_Down) return;
            const n = Math.max(1, pick.names.length);
            if (!pick.open) pick.show();
            else pick.cursor = (pick.cursor + (event.key === Qt.Key_Up ? n - 1 : 1)) % n;
            event.accepted = true;
        }

        Tile {
            id: pickTile
            icon: pick.icon
            text: String(pick.names[pick.current] || "")
            expand: true
            lit: pick.open
            onClicked: {
                if (!pick.open) pick.show();
                else if (keyed) pick.choose(pick.cursor);
                else root.focusField();
            }
            // Tab moved on: the list goes with it.
            onActiveFocusChanged: if (!activeFocus && pick.open) root.openPicker = null
        }
        GlassPane {
            id: menu
            anchors { left: parent.left; bottom: parent.top; bottomMargin: root.gap }
            width: Math.max(pickTile.width, pick.widest + root.iconSize + root.gap + root.pad * 3)
            height: rows.height + root.pad
            opacity: pick.open ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { enabled: motion.enabled; NumberAnimation { duration: motion.fast; easing.type: Easing.OutCubic } }
            transform: Translate { y: (1 - menu.opacity) * root.gap }
            Column {
                id: rows
                x: root.pad / 2; y: root.pad / 2
                width: parent.width - root.pad
                Repeater {
                    model: pick.names
                    delegate: Item {
                        id: row
                        required property int index
                        required property string modelData
                        width: rows.width; height: root.islandH
                        Lit { anchors.fill: parent; radius: root.rButton; active: pick.open && row.index === pick.cursor; hovered: rowMouse.containsMouse }
                        Label {
                            id: rowText
                            x: root.pad
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData
                            font.weight: Font.Medium
                            onImplicitWidthChanged: pick.widest = Math.max(pick.widest, implicitWidth)
                            Component.onCompleted: pick.widest = Math.max(pick.widest, implicitWidth)
                        }
                        // The current one: a tick in the accent.
                        Icon {
                            anchors { right: parent.right; rightMargin: root.pad; verticalCenter: parent.verticalCenter }
                            name: "check"
                            color: root.cAccent
                            opacity: row.index === pick.current ? 1 : 0
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: pick.cursor = row.index
                            onClicked: pick.choose(row.index)
                        }
                    }
                }
            }
        }
    }

    /// The big clock (LockClock). Each character rolls when it changes: the
    /// old one slides up and fades while the new one comes in from below.
    component RollClock: Row {
        id: rc
        property string time: ""
        property real size: 160
        Repeater {
            // A count, not the characters: delegates stay put while digits change.
            model: rc.time.length
            delegate: Item {
                id: cell
                required property int index
                readonly property string ch: rc.time.charAt(index)
                property string shown: ch
                property string old: ""
                property real t: 1
                width: Math.max(nowT.implicitWidth, goneT.implicitWidth)
                height: nowT.implicitHeight
                clip: true
                onChChanged: {
                    if (!motion.enabled) { shown = ch; return; }
                    old = shown; shown = ch;
                    roll.restart();
                }
                NumberAnimation { id: roll; target: cell; property: "t"; from: 0; to: 1; duration: Math.round(motion.emphasized * 1.4); easing.type: Easing.OutCubic }
                Text {
                    id: goneT
                    text: cell.old; color: "white"
                    opacity: 1 - cell.t; y: -cell.t * cell.height * 0.6; visible: cell.t < 1
                    font { family: root.fontName; pixelSize: rc.size; weight: Font.Bold; features: { "tnum": 1 } }
                }
                Text {
                    id: nowT
                    text: cell.shown; color: "white"
                    opacity: cell.t; y: (1 - cell.t) * cell.height * 0.6
                    font { family: root.fontName; pixelSize: rc.size; weight: Font.Bold; features: { "tnum": 1 } }
                }
            }
        }
    }

    Component.onCompleted: { shownUser = userIndex; loadUser(); if (full) focusField(); }
}
