import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Hyprglass Control Center
//
// Peta file (cari komentar "=====" untuk lompat antar bagian):
//   1. SETTINGS & STATE   - versi, warna, nilai yang bisa diubah
//   2. LOGIC              - fungsi simpan / muat / reset / tema
//   3. PROCESSES          - perintah ke hyprctl dan python
//   4. COMPONENTS         - bagian UI yang dipakai berulang
//   5. PAGES              - isi tiga tab
//   6. HEADER & TAB BAR   - header atas dan tab bar melayang
//   7. SCRIPTS            - skrip python (teks)

FloatingWindow {
    id: root
    title: "Hyprglass Control Center"
    implicitWidth: 760
    implicitHeight: 820
    minimumSize: Qt.size(480, 720)
    // Transparan penuh: blur dan efek kaca berasal dari Hyprland / Hyprglass.
    color: "transparent"

    // ===== 1. SETTINGS & STATE =====

    // Versi (dipakai di beberapa teks)
    readonly property string pluginVersion: "1.2.0"
    readonly property string appVersion: "3.3"

    // Tampilan: ubah angka di sini untuk menyetel seluruh aplikasi
    readonly property int animFast: 140       // ms, hover dan klik
    readonly property int animNormal: 260     // ms, perpindahan dan transisi
    readonly property int cardRadius: 28
    readonly property real cardRim: 0.07      // garis tipis di tepi kartu; 0 = tanpa garis

    // Status aplikasi
    property string statusText: "Hyprglass " + pluginVersion + " ready"
    property bool glassEnabled: true
    property bool profileLoading: true
    property bool isDirty: false
    property bool isApplying: false
    property bool autoApply: false
    property string appColorScheme: "Caelestia"
    property int currentTab: 0

    // Nilai pengaturan (selain slider)
    property bool chromaticEnabled: true
    property bool fresnelEnabled: true
    property bool edgeEnabled: true
    property bool grainEnabled: false
    property bool shellGlassEnabled: true

    // Palet warna (diganti oleh tema Caelestia atau skema bawaan)
    property color accentColor: "#91bce9"
    property color accentTextColor: "#101925"
    property color panelColor: "#202936"
    property color fieldColor: "#344255"
    property color outlineColor: "#718096"
    property color primaryTextColor: "#f8fafc"
    property color secondaryTextColor: "#d1dae6"
    property color mutedTextColor: "#aebdce"
    property color trackColor: "#526174"
    property color handleColor: "#ffffff"
    property color dividerColor: "#64748b"

    // Warna berpindah halus saat tema diganti
    Behavior on accentColor { ColorAnimation { duration: root.animNormal } }
    Behavior on accentTextColor { ColorAnimation { duration: root.animNormal } }
    Behavior on panelColor { ColorAnimation { duration: root.animNormal } }
    Behavior on fieldColor { ColorAnimation { duration: root.animNormal } }
    Behavior on outlineColor { ColorAnimation { duration: root.animNormal } }
    Behavior on primaryTextColor { ColorAnimation { duration: root.animNormal } }
    Behavior on secondaryTextColor { ColorAnimation { duration: root.animNormal } }
    Behavior on mutedTextColor { ColorAnimation { duration: root.animNormal } }
    Behavior on trackColor { ColorAnimation { duration: root.animNormal } }
    Behavior on handleColor { ColorAnimation { duration: root.animNormal } }
    Behavior on dividerColor { ColorAnimation { duration: root.animNormal } }

    // Kartu: warna gelap dari palet panel.
    readonly property color cardColor: alpha(Qt.darker(panelColor, 1.7), 0.60)

    // Skema warna bawaan. Nama properti harus sama dengan properti warna di atas.
    // "Caelestia" tidak ada di sini karena warnanya dibaca dari skrip tema.
    readonly property var colorSchemes: ({
        Midnight: {
            panelColor: "#182333", fieldColor: "#26364b", outlineColor: "#526985",
            primaryTextColor: "#f3f7ff", secondaryTextColor: "#c2d0e2", mutedTextColor: "#91a5bd",
            trackColor: "#40536b", dividerColor: "#465a72", accentColor: "#83b9f5", accentTextColor: "#102033"
        },
        Graphite: {
            panelColor: "#25282d", fieldColor: "#383d44", outlineColor: "#69717c",
            primaryTextColor: "#f5f5f5", secondaryTextColor: "#c8cbd0", mutedTextColor: "#969da7",
            trackColor: "#535b66", dividerColor: "#59616b", accentColor: "#b4c4d8", accentTextColor: "#202832"
        },
        Frost: {
            panelColor: "#263746", fieldColor: "#365064", outlineColor: "#7b9bb2",
            primaryTextColor: "#f4fbff", secondaryTextColor: "#c9e0ed", mutedTextColor: "#9ab7c9",
            trackColor: "#58778c", dividerColor: "#648398", accentColor: "#9bdcf2", accentTextColor: "#16303c"
        }
    })

    // Penjelasan tiap preset
    readonly property var presetInfo: ({
        pomme: "Pomme · Apple-inspired liquid glass with a restrained lens edge and soft highlights.",
        subtle: "Subtle · Softer blur and restrained refraction.",
        clear: "Clear · Minimal blur with a clearer transparent pane.",
        glass: "Glass · A stronger, more visible glass body and colour dispersion.",
        high_contrast: "High contrast · Stronger tint and separation for busy backgrounds."
    })

    // ===== 2. LOGIC =====

    // Warna dengan alpha: alpha(root.accentColor, 0.3)
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function markDirty() {
        if (profileLoading) return
        isDirty = true
        if (autoApply) autoApplyTimer.restart()
    }

    function toggleHyprglass() {
        const next = !glassEnabled
        const lua = `local hg = hl.plugin and hl.plugin.hyprglass
if not hg then
    print("ERROR: Hyprglass not found")
else
    hg.config({ enabled = ${next} })
    print("Hyprglass ${next ? "ON" : "OFF"}")
end`
        statusText = "Toggling Hyprglass..."
        glassEnabled = next
        runner.exec(["hyprctl", "eval", lua])
    }

    function applySettings() {
        const d = JSON.stringify({
            profileVersion: 2,
            preset: presetBox.currentText,
            blur: blurSlider.value,
            refraction: refractSlider.value,
            refractionValue: refractSlider.value,
            opacity: opacitySlider.value,
            chromatic: chromaticEnabled ? chromaticSlider.value : 0,
            chromaticValue: chromaticSlider.value,
            fresnel: fresnelEnabled ? fresnelSlider.value : 0,
            fresnelValue: fresnelSlider.value,
            edge: edgeSlider.value,
            thickness: edgeEnabled ? thicknessSlider.value : 0,
            thicknessValue: thicknessSlider.value,
            noise: grainEnabled ? 0.12 : 0.0,
            chromaticEnabled: chromaticEnabled,
            fresnelEnabled: fresnelEnabled,
            edgeEnabled: edgeEnabled,
            grainEnabled: grainEnabled,
            shellGlassEnabled: shellGlassEnabled,
            autoApply: autoApply,
            appColorScheme: appColorScheme
        })
        statusText = "Saving profile and applying Hyprglass..."
        isApplying = true
        runner.exec(["python3", "-c", writerScript, d])
    }

    function resetSettings() {
        presetBox.currentIndex = 0
        // Nilai awal tiap slider ada di properti "initial" pada slider itu sendiri.
        for (const s of [blurSlider, refractSlider, opacitySlider, chromaticSlider,
                         fresnelSlider, edgeSlider, thicknessSlider])
            s.value = s.initial
        chromaticEnabled = true
        fresnelEnabled = true
        edgeEnabled = true
        grainEnabled = false
        shellGlassEnabled = true
        autoApply = false
        applyColorScheme("Caelestia")
        isDirty = true
        statusText = "Settings reset; tap the header indicator to save"
    }

    function applyColorScheme(name) {
        appColorScheme = name
        const scheme = colorSchemes[name]
        if (!scheme) {
            loadCaelestiaTheme()
            return
        }
        for (const key in scheme)
            root[key] = scheme[key]
    }

    function loadCaelestiaTheme() {
        themeLoader.exec(["python3", "-c", themeScript])
    }

    // Isi slider dengan nilai tersimpan. Kunci pertama yang ada dipakai
    // (nama baru lebih dulu, nama lama sebagai cadangan).
    function restoreSlider(slider, d, keys) {
        for (const k of keys) {
            if (d[k] !== undefined) {
                slider.value = d[k]
                return
            }
        }
    }

    function restoreProfile(d) {
        const i = presetBox.find(d.preset)
        if (i >= 0) presetBox.currentIndex = i
        restoreSlider(blurSlider, d, ["blur"])
        restoreSlider(refractSlider, d, ["refractionValue", "refraction"])
        restoreSlider(opacitySlider, d, ["opacity"])
        restoreSlider(chromaticSlider, d, ["chromaticValue", "chromatic"])
        restoreSlider(fresnelSlider, d, ["fresnelValue", "fresnel"])
        restoreSlider(edgeSlider, d, ["edge"])
        restoreSlider(thicknessSlider, d, ["thicknessValue", "thickness"])
        for (const k of ["chromaticEnabled", "fresnelEnabled", "edgeEnabled", "grainEnabled"])
            if (d[k] !== undefined) root[k] = d[k]
    }

    function loadProfile(raw) {
        let savedProfile = false
        try {
            const d = JSON.parse(raw)
            if (d.shellGlassEnabled !== undefined) shellGlassEnabled = d.shellGlassEnabled
            if (d.autoApply !== undefined) autoApply = d.autoApply
            if (d.appColorScheme !== undefined) {
                appColorScheme = d.appColorScheme
                if (d.appColorScheme !== "Caelestia") applyColorScheme(d.appColorScheme)
            }
            // Profil lama memakai rentang slider yang berbeda. Biarkan di disk,
            // dan pakai rekomendasi bawaan sampai pengguna menekan Apply.
            if (d.profileVersion === 2) {
                restoreProfile(d)
                savedProfile = true
            }
        } catch (e) {}

        if (savedProfile) {
            statusText = "Saved profile loaded"
        } else {
            isDirty = true
            statusText = "Apple Liquid Glass recommendations ready · tap the header indicator to save"
        }
        profileLoading = false
    }

    // Ganti tab: scroll ke atas dan mainkan animasi masuk halaman.
    onCurrentTabChanged: {
        scroll.contentItem.contentY = 0
        pageEnter.restart()
    }

    Component.onCompleted: {
        profileLoader.exec(["python3", "-c", profileScript])
        statusReader.exec(["hyprctl", "getoption", "plugin:hyprglass:enabled"])
        // Beri tag pada jendela ini supaya Control Center sendiri memakai preset cc_windows.
        windowTagger.exec(["hyprctl", "dispatch", "hl.dsp.window.tag({ tag = \"+hyprglass_preset_cc_windows\", window = \"title:Hyprglass Control Center\" })"])
        loadCaelestiaTheme()
        pageEnter.start()
    }

    // Animasi masuk halaman: fade dan geser sedikit dari bawah.
    ParallelAnimation {
        id: pageEnter
        NumberAnimation { target: pages; property: "opacity"; from: 0; to: 1; duration: root.animNormal; easing.type: Easing.OutCubic }
        NumberAnimation { target: pageShift; property: "y"; from: 14; to: 0; duration: 320; easing.type: Easing.OutCubic }
    }

    Timer {
        id: autoApplyTimer
        interval: 700
        repeat: false
        onTriggered: if (root.autoApply && root.isDirty && !root.isApplying) root.applySettings()
    }

    // ===== 3. PROCESSES =====

    // Menjalankan perintah (apply, toggle) dan membaca hasilnya.
    Process {
        id: runner

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (out.length === 0) return
                const low = out.toLowerCase()
                root.statusText = out.replace(/^APPLY_OK\s*/, "")
                if (out.indexOf("APPLY_OK") !== -1) {
                    root.isDirty = false
                    root.isApplying = false
                } else if (low.indexOf("failed") !== -1 || low.indexOf("error") !== -1) {
                    root.isDirty = true
                    root.isApplying = false
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    root.statusText = "Error: " + text.trim()
                    root.isApplying = false
                    root.isDirty = true
                }
            }
        }
    }

    Process {
        id: profileLoader
        stdout: StdioCollector {
            onStreamFinished: root.loadProfile(text.trim())
        }
    }

    Process { id: windowTagger }

    Process {
        id: statusReader
        stdout: StdioCollector {
            onStreamFinished: root.glassEnabled = text.indexOf("bool: true") !== -1
        }
    }

    Process {
        id: themeLoader
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text.trim())
                    if (c.accent) root.accentColor = c.accent
                    if (c.onAccent) root.accentTextColor = c.onAccent
                    if (c.surface) root.panelColor = c.surface
                    if (c.surfaceVariant) root.fieldColor = c.surfaceVariant
                    if (c.outline) root.outlineColor = c.outline
                    if (c.onSurface) root.primaryTextColor = c.onSurface
                    if (c.onSurfaceVariant) root.secondaryTextColor = c.onSurfaceVariant
                    if (c.muted) root.mutedTextColor = c.muted
                    if (c.track) root.trackColor = c.track
                    if (c.handle) root.handleColor = c.handle
                    if (c.divider) root.dividerColor = c.divider
                    if (root.appColorScheme !== "Caelestia") root.applyColorScheme(root.appColorScheme)
                    else root.statusText = "Caelestia color scheme active"
                } catch (e) {
                    root.statusText = "Could not read Caelestia theme; using fallback colors"
                }
            }
        }
    }

    // ===== 4. COMPONENTS =====

    // --- Teks ---

    component Heading: Text {
        color: root.primaryTextColor
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }

    component Caption: Text {
        Layout.fillWidth: true
        color: root.secondaryTextColor
        font.pixelSize: 11
        wrapMode: Text.Wrap
    }

    component SectionLabel: Text {
        Layout.topMargin: 6
        leftPadding: 6
        color: root.secondaryTextColor
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 0.4
    }

    // Teks status: berkedip lembut setiap kali isinya berubah.
    component StatusText: Caption {
        text: root.statusText
        color: root.accentColor
        onTextChanged: flash.restart()
        NumberAnimation on opacity {
            id: flash
            running: false
            from: 0.2; to: 1
            duration: 380
            easing.type: Easing.OutCubic
        }
    }

    // Garis kilau tipis di tepi atas kaca.
    component Highlight: Rectangle {
        property real strength: 0.3
        anchors.top: parent.top
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        height: 1
        radius: 0.5
        color: Qt.rgba(1, 1, 1, strength)
    }

    // --- Kontrol ---

    component AppButton: Button {
        id: btn
        implicitHeight: 46
        hoverEnabled: true
        scale: pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: root.animFast; easing.type: Easing.OutCubic } }

        background: Rectangle {
            radius: btn.height / 2
            color: btn.hovered ? root.alpha(root.accentColor, 0.24) : root.alpha(root.fieldColor, 0.60)
            Behavior on color { ColorAnimation { duration: root.animFast } }
        }
        contentItem: Text {
            text: btn.text
            color: btn.hovered ? root.primaryTextColor : root.secondaryTextColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: root.animFast } }
        }
    }

    // Switch: warna track memudar, knob meluncur dengan sedikit overshoot
    // dan memanjang saat ditekan.
    component AppSwitch: Item {
        id: sw
        property bool on: false
        signal flipped(bool value)
        implicitWidth: 60
        implicitHeight: 34

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sw.on ? root.accentColor : root.trackColor
            Behavior on color { ColorAnimation { duration: root.animNormal; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            width: swArea.pressed ? 32 : 26
            height: 26
            radius: 13
            anchors.verticalCenter: parent.verticalCenter
            x: sw.on ? sw.width - width - 4 : 4
            color: root.handleColor
            scale: swArea.containsMouse && !swArea.pressed ? 1.06 : 1.0

            Behavior on x { NumberAnimation { duration: root.animNormal; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            id: swArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.flipped(!sw.on)
        }
    }

    component AppComboBox: ComboBox {
        id: cb
        // true = tampilkan "high_contrast" sebagai "HIGH CONTRAST"
        property bool prettify: false
        function label(t) { return prettify ? String(t).replace("_", " ").toUpperCase() : String(t) }

        implicitHeight: 48
        hoverEnabled: true
        scale: pressed ? 0.985 : 1.0
        Behavior on scale { NumberAnimation { duration: root.animFast; easing.type: Easing.OutCubic } }

        // Panah berputar saat daftar terbuka.
        indicator: Text {
            x: cb.width - width - 20
            y: (cb.height - height) / 2
            text: "⌄"
            color: root.accentColor
            font.pixelSize: 20
            font.bold: true
            rotation: cb.popup.visible ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: root.animNormal; easing.type: Easing.OutCubic } }
        }

        background: Rectangle {
            radius: cb.height / 2
            color: root.alpha(root.fieldColor, cb.hovered ? 0.80 : 0.60)
            border.width: 1.5
            border.color: cb.popup.visible ? root.accentColor : "transparent"
            Behavior on color { ColorAnimation { duration: root.animFast } }
            Behavior on border.color { ColorAnimation { duration: root.animFast } }
        }

        contentItem: Text {
            leftPadding: 20
            rightPadding: 48
            text: cb.label(cb.displayText)
            color: root.primaryTextColor
            font.pixelSize: 12
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        delegate: ItemDelegate {
            id: dlg
            required property var modelData
            required property int index
            width: cb.width - 12
            height: 40
            highlighted: cb.highlightedIndex === dlg.index

            contentItem: Text {
                text: cb.label(dlg.modelData)
                color: dlg.highlighted ? root.accentColor : root.primaryTextColor
                font.pixelSize: 12
                font.weight: dlg.highlighted ? Font.DemiBold : Font.Medium
                verticalAlignment: Text.AlignVCenter
                leftPadding: 14
                Behavior on color { ColorAnimation { duration: root.animFast } }
            }
            background: Rectangle {
                radius: dlg.height / 2
                color: dlg.highlighted ? root.alpha(root.accentColor, 0.20)
                       : (dlg.hovered ? root.alpha(root.accentColor, 0.10) : "transparent")
                Behavior on color { ColorAnimation { duration: root.animFast } }
            }
        }

        popup: Popup {
            y: cb.height + 8
            width: cb.width
            padding: 6
            transformOrigin: Popup.Top
            implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, 270)

            // Daftar muncul dengan fade dan sedikit membesar.
            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: root.animFast }
                NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: root.animNormal; easing.type: Easing.OutCubic }
            }
            exit: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 100 }
                NumberAnimation { property: "scale"; to: 0.97; duration: 100 }
            }

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: cb.delegateModel
                currentIndex: cb.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator { }
            }
            background: Rectangle {
                radius: 26
                color: root.alpha(Qt.darker(root.panelColor, 1.25), 0.97)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
            }
        }
    }

    // Titik status bulat di header. Bisa berdenyut saat ada perubahan.
    component StatusDot: Item {
        id: dot
        property color tint: root.accentColor
        property bool lit: false          // menyala atau redup
        property bool pulsing: false      // cincin berdenyut
        property int pulseMs: 1400
        property bool clickable: true
        property string tip: ""
        signal clicked()

        width: 38
        height: 38
        scale: dotArea.pressed ? 0.88 : (dotArea.containsMouse && dot.clickable ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: root.animFast; easing.type: Easing.OutCubic } }

        // Cincin yang membesar lalu menghilang
        Rectangle {
            id: ring
            anchors.centerIn: parent
            width: 34; height: 34; radius: 17
            color: "transparent"
            border.width: 1.5
            border.color: dot.tint
            opacity: 0

            ParallelAnimation {
                running: dot.pulsing
                loops: Animation.Infinite
                onRunningChanged: if (!running) { ring.opacity = 0; ring.scale = 1 }
                NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.6; duration: dot.pulseMs; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.6; to: 0; duration: dot.pulseMs; easing.type: Easing.OutCubic }
            }
        }

        // Lingkaran luar
        Rectangle {
            anchors.centerIn: parent
            width: 34; height: 34; radius: 17
            color: dot.lit ? root.alpha(dot.tint, 0.24) : "#263d4653"
            border.width: 1
            border.color: dot.lit ? dot.tint : root.outlineColor
            Behavior on color { ColorAnimation { duration: root.animNormal } }
            Behavior on border.color { ColorAnimation { duration: root.animNormal } }
        }

        // Titik tengah
        Rectangle {
            anchors.centerIn: parent
            width: dot.lit ? 12 : 10
            height: width
            radius: width / 2
            color: dot.lit ? dot.tint : "#778391"
            opacity: dot.lit ? 1 : 0.45
            Behavior on width { NumberAnimation { duration: root.animNormal; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: root.animNormal } }
            Behavior on opacity { NumberAnimation { duration: root.animNormal } }
        }

        MouseArea {
            id: dotArea
            anchors.fill: parent
            enabled: dot.clickable
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: dot.clicked()
        }

        ToolTip.visible: dotArea.containsMouse && dot.tip.length > 0
        ToolTip.delay: 500
        ToolTip.text: dot.tip
    }

    // --- Kartu ---

    component Card: Rectangle {
        Layout.fillWidth: true
        radius: root.cardRadius
        color: root.cardColor
        border.width: root.cardRim > 0 ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, root.cardRim)
    }

    // Kartu dengan judul, deskripsi, dan satu switch di kanan.
    component ToggleCard: Card {
        id: tc
        property string title: ""
        property string description: ""
        property bool checked: false
        signal toggled(bool value)

        implicitHeight: Math.max(80, row.implicitHeight + 36)

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.margins: 18
            anchors.leftMargin: 22
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Heading { text: tc.title }
                Caption { text: tc.description }
            }

            AppSwitch {
                Layout.alignment: Qt.AlignVCenter
                on: tc.checked
                onFlipped: function(v) { tc.toggled(v) }
            }
        }
    }

    // Kartu dengan judul, deskripsi, lalu isi bebas (combo box, tombol, dll).
    component ControlCard: Card {
        id: cc
        property string title: ""
        property string description: ""
        default property alias content: slot.data

        implicitHeight: layout.implicitHeight + 40

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Heading { text: cc.title }
            Caption { text: cc.description }
            ColumnLayout {
                id: slot
                Layout.fillWidth: true
                Layout.topMargin: 4
            }
        }
    }

    // Kartu slider. Bisa punya switch aktif/nonaktif di kanan atas (toggleable).
    component SliderCard: Card {
        id: card
        property string label: ""
        property string description: ""
        property real minimum: 0
        property real maximum: 1
        property real initial: 0.5
        property int decimals: 2
        property alias value: slider.value

        property bool toggleable: false
        property bool checked: true
        signal toggled(bool value)

        // Slider dan kotak angka redup saat switch dimatikan.
        readonly property bool active: !toggleable || checked

        implicitHeight: column.implicitHeight + 40

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 20
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Heading { text: card.label }
                    Caption { text: card.description }
                }

                TextField {
                    id: valueInput
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 32
                    enabled: card.active
                    opacity: card.active ? 1 : 0.38
                    Behavior on opacity { NumberAnimation { duration: root.animNormal } }

                    text: slider.value.toFixed(card.decimals)
                    color: root.primaryTextColor
                    selectionColor: root.accentColor
                    selectedTextColor: root.accentTextColor
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    selectByMouse: true
                    validator: DoubleValidator {
                        bottom: card.minimum
                        top: card.maximum
                        decimals: 4
                    }
                    background: Rectangle {
                        radius: 16
                        color: root.alpha(root.fieldColor, 0.60)
                        border.width: 1.5
                        border.color: valueInput.activeFocus ? root.accentColor : "transparent"
                        Behavior on border.color { ColorAnimation { duration: root.animFast } }
                    }
                    onEditingFinished: {
                        const parsed = Number(text)
                        if (text.trim().length > 0 && Number.isFinite(parsed))
                            slider.value = Math.max(card.minimum, Math.min(card.maximum, parsed))
                        // Pasang ulang binding supaya teks ikut slider lagi.
                        text = Qt.binding(() => slider.value.toFixed(card.decimals))
                    }
                }

                AppSwitch {
                    visible: card.toggleable
                    Layout.alignment: Qt.AlignVCenter
                    on: card.checked
                    onFlipped: function(v) { card.toggled(v) }
                }
            }

            Slider {
                id: slider
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                hoverEnabled: true
                enabled: card.active
                opacity: card.active ? 1 : 0.38
                Behavior on opacity { NumberAnimation { duration: root.animNormal } }

                from: card.minimum
                to: card.maximum
                value: card.initial
                onValueChanged: root.markDirty()

                background: Rectangle {
                    x: slider.leftPadding
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: slider.availableWidth
                    height: 8
                    radius: 4
                    color: root.trackColor

                    // Bagian terisi. Meluncur halus saat nilai diubah lewat kode
                    // (reset, muat profil), tapi langsung mengikuti saat digeser.
                    Rectangle {
                        width: slider.visualPosition * parent.width
                        height: parent.height
                        radius: 4
                        color: root.accentColor
                        Behavior on width {
                            enabled: !slider.pressed
                            NumberAnimation { duration: root.animNormal; easing.type: Easing.OutCubic }
                        }
                    }
                }

                handle: Rectangle {
                    x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                    y: slider.topPadding + slider.availableHeight / 2 - height / 2
                    width: 22
                    height: 22
                    radius: 11
                    color: root.handleColor
                    scale: slider.pressed ? 1.1 : (slider.hovered ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: root.animFast; easing.type: Easing.OutCubic } }
                    Behavior on x {
                        enabled: !slider.pressed
                        NumberAnimation { duration: root.animNormal; easing.type: Easing.OutCubic }
                    }

                    // Lingkaran lembut di belakang handle saat disentuh.
                    Rectangle {
                        z: -1
                        anchors.centerIn: parent
                        width: slider.pressed ? 42 : 24
                        height: width
                        radius: width / 2
                        color: root.alpha(root.accentColor, 0.28)
                        opacity: slider.pressed ? 1 : 0
                        Behavior on width { NumberAnimation { duration: root.animFast; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: root.animFast } }
                    }
                }
            }
        }
    }

    // ===== 5. PAGES =====

    ScrollView {
        id: scroll
        anchors.top: header.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        leftPadding: 20
        rightPadding: 20
        topPadding: 4
        bottomPadding: 0
        clip: true
        contentWidth: availableWidth
        // Hanya tab Configuration yang bisa di-scroll; tab lain selalu muat.
        contentHeight: root.currentTab === 0 ? contentLayout.implicitHeight : availableHeight

        ScrollBar.vertical: ScrollBar {
            id: vbar
            policy: root.currentTab === 0 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            contentItem: Rectangle {
                implicitWidth: 5
                radius: 3
                color: root.alpha(root.secondaryTextColor, 0.55)
                opacity: vbar.active ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: root.animNormal } }
            }
        }

        ColumnLayout {
            id: contentLayout
            width: Math.min(scroll.availableWidth, 620)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            StackLayout {
                id: pages
                Layout.fillWidth: true
                currentIndex: root.currentTab
                transform: Translate { id: pageShift }

                // ----- Tab 0: Configuration -----
                ColumnLayout {
                    id: configurationPage
                    Layout.fillWidth: true
                    spacing: 12

                    Card {
                        radius: 32
                        implicitHeight: 104

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            Rectangle {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                radius: 28
                                color: root.alpha(root.accentColor, 0.18)
                                Text {
                                    anchors.centerIn: parent
                                    text: "◈"
                                    color: root.accentColor
                                    font.pixelSize: 29
                                }
                            }

                            ColumnLayout {
                                spacing: 3
                                Text {
                                    text: "Liquid Glass"
                                    color: root.primaryTextColor
                                    font.pixelSize: 19
                                    font.bold: true
                                }
                                Text {
                                    text: "Configure your desktop glass effects"
                                    color: root.secondaryTextColor
                                    font.pixelSize: 12
                                }
                                Text {
                                    text: "Hyprglass plugin · Version " + root.pluginVersion
                                    color: root.mutedTextColor
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }

                    SectionLabel { text: "Appearance preset" }

                    AppComboBox {
                        id: presetBox
                        Layout.fillWidth: true
                        prettify: true
                        model: ["pomme", "subtle", "clear", "glass", "high_contrast"]
                        currentIndex: 0
                        onActivated: root.markDirty()
                    }

                    Caption {
                        Layout.leftMargin: 6
                        text: root.presetInfo[presetBox.currentText] || ""
                        color: root.mutedTextColor
                    }

                    SectionLabel { text: "Glass parameters" }

                    SliderCard {
                        id: blurSlider
                        label: "Blur strength"
                        description: "Background frosting intensity"
                        maximum: 6
                        initial: 1.5
                    }

                    SliderCard {
                        id: refractSlider
                        label: "Refraction"
                        description: "Edge bending intensity · 0.0–10.0"
                        maximum: 10
                        initial: 1.2
                        decimals: 1
                    }

                    SliderCard {
                        id: opacitySlider
                        label: "Glass opacity"
                        description: "Overall pane transparency · 0.0–1.0"
                        initial: 0.82
                    }

                    SliderCard {
                        id: chromaticSlider
                        label: "Chromatic aberration"
                        description: "Subtle rainbow dispersion · 0.0–1.0"
                        initial: 0.08
                        toggleable: true
                        checked: root.chromaticEnabled
                        onToggled: function(value) { root.chromaticEnabled = value; root.markDirty() }
                    }

                    SliderCard {
                        id: fresnelSlider
                        label: "Fresnel highlights"
                        description: "Soft glass edge glow · 0.0–1.0"
                        initial: 0.30
                        toggleable: true
                        checked: root.fresnelEnabled
                        onToggled: function(value) { root.fresnelEnabled = value; root.markDirty() }
                    }

                    SliderCard {
                        id: edgeSlider
                        label: "Lens edge height"
                        description: "Lens edge height in logical pixels · 0–60"
                        maximum: 60
                        initial: 24
                        decimals: 1
                    }

                    SliderCard {
                        id: thicknessSlider
                        label: "Edge thickness"
                        description: "Glass rim width in logical pixels · 0–10"
                        maximum: 10
                        initial: 5.0
                        decimals: 1
                        toggleable: true
                        checked: root.edgeEnabled
                        onToggled: function(value) { root.edgeEnabled = value; root.markDirty() }
                    }

                    ToggleCard {
                        title: "Frosted grain"
                        description: "Fine frosted texture · fixed strength 0.12 when enabled"
                        checked: root.grainEnabled
                        onToggled: function(value) { root.grainEnabled = value; root.markDirty() }
                    }

                    StatusText { Layout.topMargin: 4; Layout.leftMargin: 6 }

                    Caption {
                        Layout.leftMargin: 6
                        text: "Changes stay temporary until you tap the status dot in the header or enable Auto Apply."
                        color: root.mutedTextColor
                    }

                    Item { Layout.preferredHeight: 12 }
                }

                // ----- Tab 1: App Settings -----
                ColumnLayout {
                    id: appSettingsPage
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    SectionLabel { text: "Application settings" }

                    ToggleCard {
                        title: "Caelestia Shell"
                        description: "Apply the Hyprglass effect to Caelestia layers, or exclude them."
                        checked: root.shellGlassEnabled
                        onToggled: function(value) { root.shellGlassEnabled = value; root.markDirty() }
                    }

                    ControlCard {
                        title: "App color scheme"
                        description: "Choose the Control Center color theme."

                        AppComboBox {
                            Layout.fillWidth: true
                            model: ["Caelestia", "Midnight", "Graphite", "Frost"]
                            currentIndex: Math.max(0, model.indexOf(root.appColorScheme))
                            onActivated: {
                                root.applyColorScheme(currentText)
                                root.markDirty()
                            }
                        }
                    }

                    ToggleCard {
                        title: "Auto Apply"
                        description: "Automatically apply changes shortly after you stop adjusting values."
                        checked: root.autoApply
                        onToggled: function(value) { root.autoApply = value; root.markDirty() }
                    }

                    ControlCard {
                        title: "Reset to defaults"
                        description: "Restore all values and app preferences to the recommended defaults."

                        AppButton {
                            Layout.fillWidth: true
                            text: "Reset all settings"
                            onClicked: root.resetSettings()
                        }
                    }

                    StatusText { Layout.topMargin: 4; Layout.leftMargin: 6 }
                }

                // ----- Tab 2: About -----
                ColumnLayout {
                    id: aboutPage
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 14

                    Card {
                        radius: 32
                        implicitHeight: 170

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "◈"
                                color: root.accentColor
                                font.pixelSize: 44
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Hyprglass Control Center"
                                color: root.primaryTextColor
                                font.pixelSize: 19
                                font.bold: true
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Version " + root.appVersion + " · Hyprglass " + root.pluginVersion
                                color: root.secondaryTextColor
                                font.pixelSize: 11
                            }
                        }
                    }

                    SectionLabel { text: "About" }
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        text: "A native Quickshell control interface for configuring Hyprglass Liquid Glass effects on Hyprland, with dedicated integration settings for Caelestia Shell."
                        color: root.primaryTextColor
                        font.pixelSize: 12
                        lineHeight: 1.3
                        wrapMode: Text.Wrap
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.dividerColor; opacity: 0.4 }

                    SectionLabel { text: "Components" }
                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        text: "• Hyprglass plugin\n• Quickshell interface\n• Hyprland compositor\n• Caelestia Shell integration"
                        color: root.primaryTextColor
                        font.pixelSize: 12
                        lineHeight: 1.4
                        wrapMode: Text.Wrap
                    }

                    Caption {
                        Layout.leftMargin: 6
                        text: "Designed with an Apple-inspired translucent interface. Colour accents can follow the active Caelestia scheme."
                        color: root.mutedTextColor
                    }
                }
            }

            // Ruang kosong supaya kartu terakhir bisa di-scroll di atas tab bar.
            Item { Layout.preferredHeight: tabBar.height + 28 }
        }
    }

    // ===== 6. HEADER & TAB BAR =====

    // Header tetap (di luar area scroll)
    Rectangle {
        id: header
        z: 10
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 40, 620)
        height: 68
        radius: 34
        color: root.alpha(root.fieldColor, 0.55)
        border.width: 1
        border.color: root.alpha(root.outlineColor, 0.45)

        Highlight { width: parent.width - parent.height; strength: 0.22 }

        // Kiri: indikator Hyprglass (klik untuk menyalakan / mematikan)
        StatusDot {
            anchors.left: parent.left
            anchors.leftMargin: 17
            anchors.verticalCenter: parent.verticalCenter
            tint: "#65e59a"
            lit: root.glassEnabled
            tip: root.glassEnabled ? "Turn Hyprglass off" : "Turn Hyprglass on"
            onClicked: root.toggleHyprglass()
        }

        // Tengah: judul
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Hyprglass"
                color: root.primaryTextColor
                font.pixelSize: 21
                font.bold: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Liquid glass control center"
                color: root.secondaryTextColor
                font.pixelSize: 10
                font.letterSpacing: 0.6
            }
        }

        // Kanan: titik Apply. Berdenyut saat ada perubahan, lebih cepat saat menyimpan.
        StatusDot {
            anchors.right: parent.right
            anchors.rightMargin: 17
            anchors.verticalCenter: parent.verticalCenter
            tint: root.accentColor
            lit: root.isDirty
            pulsing: root.isDirty
            pulseMs: root.isApplying ? 650 : 1500
            clickable: root.isDirty && !root.isApplying
            tip: root.isApplying ? "Applying..." : (root.isDirty ? "Apply changes" : "Nothing to apply")
            onClicked: root.applySettings()
        }
    }

    // Tab bar melayang (ikon saja, kaca dengan blur latar)
    Item {
        id: tabBar
        z: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        anchors.horizontalCenter: parent.horizontalCenter

        readonly property int cellWidth: 72
        readonly property int cellHeight: 50
        readonly property int pad: 7
        readonly property int gap: 6
        // Area ekstra di sekeliling bar supaya blur tidak memudar di tepi.
        readonly property int bm: 16
        readonly property var tabs: [
            { symbol: "◈", label: "Configuration" },
            { symbol: "⚙", label: "App Settings" },
            { symbol: "ⓘ", label: "About" }
        ]

        width: pad * 2 + tabs.length * cellWidth + (tabs.length - 1) * gap
        height: cellHeight + pad * 2

        // 1) Blur latar: menangkap konten yang ter-scroll di belakang bar.
        ShaderEffectSource {
            id: tabBackdrop
            x: -tabBar.bm
            y: -tabBar.bm
            width: tabBar.width + tabBar.bm * 2
            height: tabBar.height + tabBar.bm * 2
            sourceItem: scroll
            sourceRect: Qt.rect(tabBar.x - tabBar.bm - scroll.x,
                                tabBar.y - tabBar.bm - scroll.y,
                                width, height)
            live: true
            visible: false
        }

        // Mask berbentuk pil, sama dengan bentuk bar.
        Item {
            id: tabMask
            x: -tabBar.bm
            y: -tabBar.bm
            width: tabBar.width + tabBar.bm * 2
            height: tabBar.height + tabBar.bm * 2
            visible: false
            layer.enabled: true
            Rectangle {
                x: tabBar.bm
                y: tabBar.bm
                width: tabBar.width
                height: tabBar.height
                radius: height / 2
            }
        }

        MultiEffect {
            x: -tabBar.bm
            y: -tabBar.bm
            width: tabBar.width + tabBar.bm * 2
            height: tabBar.height + tabBar.bm * 2
            source: tabBackdrop
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: -0.2
            brightness: -0.05
            maskEnabled: true
            maskSource: tabMask
        }

        // 2) Badan kaca: lapisan warna di atas blur, dengan garis tepi tipis.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.alpha(root.panelColor, 0.42) }
                GradientStop { position: 1.0; color: root.alpha(root.panelColor, 0.58) }
            }
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.16)
        }

        Highlight { width: parent.width - parent.height; strength: 0.30 }

        // 3) Kartu tab aktif: meluncur ke tab terpilih dengan sedikit pantulan.
        Rectangle {
            id: activeCard
            width: tabBar.cellWidth
            height: tabBar.cellHeight
            y: tabBar.pad
            x: tabBar.pad + root.currentTab * (tabBar.cellWidth + tabBar.gap)
            radius: height / 2

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.alpha(root.accentColor, 0.48) }
                GradientStop { position: 1.0; color: root.alpha(root.accentColor, 0.26) }
            }

            Highlight { width: parent.width * 0.5; strength: 0.40 }

            Behavior on x {
                NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
            }
        }

        // 4) Ikon tab
        Row {
            x: tabBar.pad
            y: tabBar.pad
            spacing: tabBar.gap

            Repeater {
                model: tabBar.tabs
                delegate: Item {
                    id: cell
                    required property int index
                    required property var modelData
                    readonly property bool active: root.currentTab === index
                    readonly property bool lit: active || tabMouse.containsMouse

                    width: tabBar.cellWidth
                    height: tabBar.cellHeight
                    scale: tabMouse.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: root.animFast; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.symbol
                        font.pixelSize: 25
                        color: cell.lit ? root.primaryTextColor : root.secondaryTextColor
                        opacity: cell.lit ? 1.0 : 0.75
                        scale: cell.active ? 1.12 : 1.0
                        Behavior on color { ColorAnimation { duration: root.animFast } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: root.animFast; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentTab = cell.index
                    }

                    ToolTip.visible: tabMouse.containsMouse
                    ToolTip.delay: 500
                    ToolTip.text: cell.modelData.label
                }
            }
        }
    }

    // ===== 7. SCRIPTS =====
    // Skrip python berupa teks. Isinya tidak diubah dari versi sebelumnya.
    // Catatan: karena berada di dalam template string JavaScript, tanda "\\"
    // di bawah sampai ke python sebagai satu "\".

    // Membaca profil tersimpan dan status glass milik Caelestia.
    readonly property string profileScript: `import pathlib,json
cfg=pathlib.Path.home()/".config/hyprglass-control"
p=cfg/"profile.json"
s=cfg/"caelestia-shell.profile"
d=json.loads(p.read_text()) if p.exists() else {}
d["shellGlassEnabled"]=("enabled=true" in s.read_text().splitlines()) if s.exists() else d.get("shellGlassEnabled", True)
print(json.dumps(d))
`

    // Membaca skema Caelestia dan mencetak palet dalam JSON.
    readonly property string themeScript: `import pathlib,json,re
p=pathlib.Path.home()/".local/state/caelestia/scheme.json"
data={}
if p.exists():
    raw=p.read_text()
    try:
        obj=json.loads(raw)
        def walk(x):
            if isinstance(x,dict):
                for k,v in x.items():
                    if isinstance(v,(dict,list)): walk(v)
                    else: data[re.sub(r"(?<!^)(?=[A-Z])","_",str(k)).lower().replace("-","_")]=str(v)
            elif isinstance(x,list):
                for v in x: walk(v)
        walk(obj)
    except Exception:
        for line in raw.splitlines():
            m=re.match(r"\\s*([\\w-]+)\\s+(#[0-9a-fA-F]{6,8}|[0-9a-fA-F]{6,8})",line)
            if m: data[re.sub(r"(?<!^)(?=[A-Z])","_",m.group(1)).lower().replace("-","_")]=m.group(2)
def pick(keys, fallback):
    for k in keys:
        v=data.get(k)
        if isinstance(v,str) and re.fullmatch(r"#?[0-9a-fA-F]{6,8}",v):
            return v if v.startswith("#") else "#"+v
    return fallback
out={
"accent":pick(["primary","accent","primary_fixed"],"#91bce9"),
"onAccent":pick(["on_primary","on_accent"],"#101925"),
"surface":pick(["surface_container","surface_container_low","surface"],"#382b394b"),
"surfaceVariant":pick(["surface_container_high","surface_variant","surface_container"],"#553b526b"),
"outline":pick(["outline_variant","outline"],"#668da9c8"),
"onSurface":pick(["on_surface","text"],"#edf3fc"),
"onSurfaceVariant":pick(["on_surface_variant","secondary_text"],"#9baabd"),
"muted":pick(["outline","on_surface_variant"],"#778496"),
"track":pick(["surface_container_highest","surface_variant"],"#554c5b70"),
"handle":pick(["on_primary","on_surface"],"#edf6ff"),
"divider":pick(["outline_variant"],"#303642")}
print(json.dumps(out))
`

    // Menyimpan profil ke disk, reload Hyprland, lalu menerapkan profil Caelestia.
    readonly property string writerScript: `import pathlib,sys,subprocess,json
p=pathlib.Path.home()/".config/hyprglass-control/profile.json"
p.parent.mkdir(parents=True,exist_ok=True)
d=json.loads(sys.argv[1])
p.write_text(json.dumps(d,separators=(",",":")))
shell_profile=p.parent/"caelestia-shell.profile"
shell_profile.write_text("schema=1\\nenabled="+("true" if d.get("shellGlassEnabled",True) else "false")+"\\npreset=cc_shell\\nlayers=caelestia-drawers,caelestia-background\\n")
r=subprocess.run(["hyprctl","reload"],capture_output=True,text=True)
if r.returncode:
    print("Hyprland reload failed: "+(r.stderr.strip() or r.stdout.strip()))
    sys.exit(r.returncode)
lua = r'''local hg = hl.plugin and hl.plugin.hyprglass
if not hg then error("Hyprglass is not active or not loaded") end
local f = io.open(os.getenv("HOME") .. "/.config/hyprglass-control/caelestia-shell.profile", "r")
local profile = f and f:read("*a") or nil
if f then f:close() end
local enabled = (profile == nil) or (profile:match("enabled=true") ~= nil)
if enabled then
  hg.config({ layers = { enabled = true, manage_blur = true, mask_threshold = 0.05 } })
  hg.layer("caelestia-drawers", { exclude = false, preset = "cc_shell", mask_mode = "contour", mask_threshold = 0.05, mask_feather = 0.08 })
  hg.layer("caelestia-background", { exclude = false, preset = "cc_shell" })
else
  hg.layer("caelestia-drawers", { exclude = true })
  hg.layer("caelestia-background", { exclude = true })
end
print("SHELL_PROFILE_APPLIED=" .. tostring(enabled))'''
e=subprocess.run(["hyprctl","eval",lua],capture_output=True,text=True)
if e.returncode or "error" in (e.stdout+e.stderr).lower():
    print("Profile saved, but applying the Caelestia profile failed: "+(e.stderr.strip() or e.stdout.strip()))
    sys.exit(e.returncode or 1)
print("APPLY_OK")
print("Main profile and Caelestia profile saved · "+e.stdout.strip())
`
}
