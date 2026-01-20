// noinspection LongLine

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQml 2.15
import Qt5Compat.GraphicalEffects

Item {
    id: root
    focus: true

    Component.onCompleted: forceActiveFocus()

    // ===== API =====
    property var stackModel: null
    property string historyText: ""
    property string decimalSeparator: "."
    property bool canUndo: false
    property bool canRedo: false

    property var stackChangeCallback: null
    property string inputText: ""
    property string displayText: ""

    property alias inputItem: root
    property alias stackCurrentIndex: stackList.currentIndex
    property alias stackCurrentItem: stackList.currentItem
    readonly property int stackCount: stackList.count
    readonly property bool isStackEditing: (stackList && stackList.currentItem) ? stackList.currentItem.editing : false

    signal inputEnter()
    signal keypadAction(var key)
    signal keyPressed(var event)
    signal pushPi()
    signal pushE()
    signal undoRequest()
    signal redoRequest()
    signal clearAllRequest()
    signal clearHistoryRequest()
    signal stackRemoveRequest(int index)
    signal stackMoveRequest(int delta)
    signal stackValueSet(int row, string text)

    function forceInputFocus() { root.forceActiveFocus() }
    function ensureStackVisible(idx) { stackList.positionViewAtIndex(idx, ListView.Visible) }
    function showToast(msg) { toast.show(msg) }
    function focusKeypad() { keypad.focusFirst() }

    function simulatePress(rawInput) {
        return keypad.simulatePress(rawInput)
    }


    // ===== OBSŁUGA KLAWISZY (GLOBALNA) =====
    Keys.onPressed: (event) => {
        root.keyPressed(event);
    }

    // ===== Style =====
    readonly property int cornerRadius: 12
    readonly property int splitHandleH: 8
    readonly property int stackMinH: 100
    readonly property int historyMinH: 80  

    // ===== KeyButton Component =====
    component KeyButton: Button {
        id: btn
        property var key
        focusPolicy: Qt.StrongFocus
        Layout.preferredHeight: 34
        Layout.fillWidth: true
        Layout.minimumHeight: 20
        Layout.maximumHeight: 34
        Layout.minimumWidth: 55
        Layout.preferredWidth: 55

        // Pobieramy separator z roota, jeśli label to DECIMAL
        text: (key && key.label === "DECIMAL") ? root.decimalSeparator : ((key && key.label) ? key.label : "")

        Timer { id: releaseTimer; interval: 100; onTriggered: btn.down = false }
        function flash() { btn.down = true; releaseTimer.restart() }

        onClicked: {
            btn.flash()
            if (key.label === "DECIMAL") {
                root.keypadAction({ label: root.decimalSeparator, type: key.type, value: root.decimalSeparator })
            } else {
                root.keypadAction(key)
            }
        }

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) return;

            if (event.modifiers & Qt.ShiftModifier) {
                if (event.key === Qt.Key_Up) { root.stackMoveRequest(-1); event.accepted = true; return }
                if (event.key === Qt.Key_Down) { root.stackMoveRequest(1); event.accepted = true; return }
            }
            if (event.key === Qt.Key_Escape) { root.forceActiveFocus(); event.accepted = true; return }
            if (event.key === Qt.Key_Space) { if (!event.isAutoRepeat) { btn.flash(); btn.clicked() }; event.accepted = true; return }

            let raw = event.text
            if (event.key === Qt.Key_Backspace) raw = "BACK"
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) raw = "ENTER"

            if (root.simulatePress(raw)) event.accepted = true
        }
    }

    // ===== Layout =====
    ColumnLayout {
        anchors.fill: parent; spacing: 2

        // EKRAN LCD
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 50
            color: root.palette.base; radius: 8
            border.color: root.palette.mid; border.width: 1
            MouseArea { anchors.fill: parent; onClicked: root.forceActiveFocus() }

            Text {
                id: displayLabel
                anchors.fill: parent; anchors.margins: 10
                text: root.displayText
                font.family: "Monospace"; font.pointSize: 20
                horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                color: root.palette.text; elide: Text.ElideLeft
            }
        }

        // Toolbar
        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 55; spacing: 2
            Button { text: "π"; Layout.fillWidth: true; onClicked: root.pushPi() }
            Button { text: "e"; Layout.fillWidth: true; onClicked: root.pushE() }
            Button { text: "↶"; Layout.fillWidth: true; enabled: root.canUndo; onClicked: root.undoRequest() }
            Button { text: "↷"; Layout.fillWidth: true; enabled: root.canRedo; onClicked: root.redoRequest() }
            Button { text: "CLR"; Layout.fillWidth: true; onClicked: root.clearAllRequest() }
        }

        // SplitView
        SplitView {
            id: panes
            Layout.fillWidth: true; Layout.fillHeight: true; orientation: Qt.Vertical; clip: true
            handle: Rectangle { implicitHeight: root.splitHandleH; color: panes.palette.mid; opacity: 0.6; radius: 4 }
            property real stackRatio: 0.70
            property bool applying: false
            function applyRatio() {
                applying = true
                const available = Math.max(0, panes.height - root.splitHandleH)
                const minS = stackFrame.SplitView.minimumHeight || 0
                const minH = historyFrame.SplitView.minimumHeight || 0
                let s = Math.round(available * stackRatio)
                s = Math.max(0, Math.min(available, s))
                let h = available - s
                if (s < minS) { s = Math.min(minS, available); h = available - s }
                if (h < minH) { h = Math.min(minH, available); s = available - h }
                stackFrame.SplitView.preferredHeight = s
                historyFrame.SplitView.preferredHeight = h
                applying = false
            }
            onHeightChanged: applyRatio()
            Component.onCompleted: Qt.callLater(applyRatio)
            Timer { id: sampleRatio; interval: 0; repeat: false; onTriggered: { if (panes.applying) return; const available = Math.max(1, panes.height - root.splitHandleH); panes.stackRatio = Math.max(0.05, Math.min(0.95, stackFrame.height / available)) } }
            Connections { target: stackFrame; function onHeightChanged() { sampleRatio.restart() } }
            Connections { target: historyFrame; function onHeightChanged() { sampleRatio.restart() } }

            // Stack Frame
            Frame {
                id: stackFrame
                padding: 0; SplitView.minimumHeight: root.stackMinH
                background: Rectangle { id: stackBg; radius: root.cornerRadius; color: stackFrame.palette.window; border.color: stackFrame.palette.mid; border.width: 1 }
                Item {
                    id: stackClip
                    anchors.fill: parent; anchors.margins: stackBg.border.width
                    layer.enabled: true; layer.smooth: true
                    layer.effect: OpacityMask { maskSource: Rectangle { width: stackClip.width; height: stackClip.height; radius: Math.max(0, root.cornerRadius - stackBg.border.width); color: "white" } }
                    RowLayout {
                        anchors.fill: parent; spacing: 0
                        ListView {
                            id: stackList
                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                            model: root.stackModel; currentIndex: -1
                            property int rowHeight: 40
                            property bool showStackBar: false
                            Timer { id: stackBarTimer; interval: 700; repeat: false; onTriggered: stackList.showStackBar = false }
                            onContentYChanged: { stackList.showStackBar = true; stackBarTimer.restart() }
                            onMovementStarted: { stackList.showStackBar = true; stackBarTimer.restart() }
                            onMovementEnded: stackBarTimer.restart()
                            ScrollBar.vertical: ScrollBar { id: stackVBar; policy: ScrollBar.AsNeeded; hoverEnabled: true; z: 100; width: 12; padding: 2; readonly property bool needed: stackList.contentHeight > stackList.height + 1; visible: needed; opacity: needed ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } }

                            delegate: Item {
                                id: rowItem
                                width: stackList.width; height: stackList.rowHeight
                                property bool editing: false
                                readonly property bool isSelected: ListView.isCurrentItem
                                function startEdit() {
                                    editing = true
                                    editField.text = model.value
                                    editField.forceActiveFocus()
                                    editField.selectAll()
                                }
                                HoverHandler { id: hoverH }
                                Rectangle { anchors.fill: parent; color: rowItem.isSelected ? stackFrame.palette.highlight : (hoverH.hovered ? Qt.lighter(root.palette.highlight, 1.6) : stackFrame.palette.base); opacity: rowItem.isSelected ? 1.0 : (hoverH.hovered ? 0.22 : 1.0); Behavior on color { ColorAnimation { duration: 80 } } Behavior on opacity { NumberAnimation { duration: 80 } } }
                                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: stackFrame.palette.mid }
                                MouseArea {
                                    id: rowMouse; anchors.left: parent.left; anchors.right: removeBtn.left; anchors.top: parent.top; anchors.bottom: parent.bottom; enabled: !rowItem.editing
                                    acceptedButtons: Qt.LeftButton; onClicked: { stackList.currentIndex = index; root.forceActiveFocus() }
                                    onDoubleClicked: { stackList.currentIndex = index; rowItem.startEdit()}
                                }
                                Text { id: idxText; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: (index + 1).toString(); color: rowItem.isSelected ? stackFrame.palette.highlightedText : stackFrame.palette.text; font.family: "Monospace" }
                                Rectangle { id: vSep; width: 1; anchors.left: idxText.right; anchors.leftMargin: 12; anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.topMargin: 4; anchors.bottomMargin: 4; color: rowItem.isSelected ? stackFrame.palette.highlightedText : stackFrame.palette.mid; opacity: 0.5 }
                                Text { id: valueText; anchors.left: vSep.right; anchors.leftMargin: 12; anchors.right: removeBtn.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: model.value; visible: !rowItem.editing; color: rowItem.isSelected ? stackFrame.palette.highlightedText : stackFrame.palette.text; font.family: "Monospace"; elide: Text.ElideLeft }

                                // Edycja na stosie
                                TextField {
                                    id: editField
                                    anchors.left: vSep.right; anchors.leftMargin: 12
                                    anchors.right: removeBtn.left; anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 30
                                    visible: rowItem.editing
                                    font.family: "Monospace"
                                    selectByMouse: true
                                    Keys.priority: Keys.BeforeItem

                                    // [NOWOŚĆ] Zmienna do śledzenia poprzedniej długości
                                    property string previousText: ""

                                    onTextEdited: {
                                        // 1. Jeśli tekst jest KRÓTSZY niż wcześniej (user kasuje), ZAWSZE pozwalamy.
                                        // Dzięki temu można skrócić wynik z 17 cyfr do 15 i dopiero edytować.
                                        if (text.length < previousText.length) {
                                            previousText = text
                                            return
                                        }

                                        // 2. Jeśli tekst się wydłużył lub zmienił bez zmiany długości, sprawdzamy limit.
                                        let contentToCheck = text

                                        // Logika dla notacji naukowej (ignorujemy wykładnik)
                                        if (text.indexOf("*") >= 0) {
                                            contentToCheck = text.split("*")[0]
                                        } else if (text.toLowerCase().indexOf("e") >= 0) {
                                            contentToCheck = text.toLowerCase().split("e")[0]
                                        }

                                        const digits = contentToCheck.replace(/[^0-9]/g, "").length

                                        if (digits > 15) {
                                            undo()
                                            root.showToast("Maksymalna precyzja (15 cyfr)")
                                        } else {
                                            // Akceptujemy zmianę
                                            previousText = text
                                        }
                                    }

                                    function commit() {
                                        let success = false
                                        if (root.stackChangeCallback) {
                                            success = root.stackChangeCallback(index, text)
                                        } else if (root.stackModel) {
                                            success = root.stackModel.setValueAt(index, text)
                                        }

                                        if (success) {
                                            rowItem.editing = false
                                            root.forceActiveFocus()
                                        } else {
                                            toast.show("Nieprawidłowa liczba")
                                            forceActiveFocus()
                                            selectAll()
                                        }
                                    }

                                    Keys.onReturnPressed: (e) => { commit(); e.accepted = true }
                                    Keys.onEnterPressed: (e) => { commit(); e.accepted = true }
                                    Keys.onEscapePressed: (e) => { rowItem.editing = false; root.forceActiveFocus(); e.accepted = true }
                                    onEditingFinished: { if (rowItem.editing) commit() }
                                }                                MouseArea { anchors.fill: parent; visible: rowItem.editing; z: 999; onClicked: editField.commit() }
                                ToolButton { id: removeBtn; anchors.right: parent.right; anchors.rightMargin: 6 + (stackVBar.visible ? stackVBar.width : 0); anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; text: "✕"; onClicked: root.stackRemoveRequest(index) }
                            }
                        }
                        // Arrows Panel
                        Rectangle {
                            id: arrowsPanel; Layout.preferredWidth: 48; Layout.fillHeight: true; color: stackFrame.palette.window
                            Rectangle { width: 1; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; color: stackFrame.palette.mid }
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 6; spacing: 6
                                ToolButton { text: "▲"; Layout.fillWidth: true; enabled: stackList.currentIndex > 0; onClicked: root.stackMoveRequest(-1) }
                                ToolButton { text: "▼"; Layout.fillWidth: true; enabled: stackList.currentIndex >= 0 && stackList.currentIndex < stackList.count - 1; onClicked: root.stackMoveRequest(+1) }
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }
            }
            // History
            Frame {
                id: historyFrame
                padding: 6
                SplitView.minimumHeight: root.historyMinH
                background: Rectangle {
                    radius: root.cornerRadius
                    color: historyFrame.palette.window
                    border.color: historyFrame.palette.mid
                    border.width: 1
                }

                ColumnLayout {
                    anchors.fill: parent; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "History"; opacity: 0.85 }
                        Item { Layout.fillWidth: true }
                        ToolButton { text: "Clear"; onClicked: root.clearHistoryRequest() }
                    }

                    Flickable {
                        id: historyFlick
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        contentWidth: width
                        contentHeight: historyTextDisplay.implicitHeight

                        property bool showHistBars: false
                        Timer { id: histBarTimer; interval: 700; repeat: false; onTriggered: historyFlick.showHistBars = false }
                        onContentYChanged: { historyFlick.showHistBars = true; histBarTimer.restart() }
                        onMovementStarted: { historyFlick.showHistBars = true; histBarTimer.restart() }
                        onMovementEnded: histBarTimer.restart()

                        ScrollBar.vertical: ScrollBar {
                            id: histVBar
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            z: 100; width: 10; padding: 2
                            readonly property bool needed: historyFlick.contentHeight > historyFlick.height + 1
                            visible: needed
                            opacity: (needed && (historyFlick.showHistBars || pressed || hovered)) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }
                        

                        TextEdit {
                            id: historyTextDisplay
                            x: 0; y: 0
                            text: root.historyText
                            readOnly: true
                            selectByMouse: true
                            width: parent.width
                            wrapMode: TextEdit.Wrap

                            font.family: "Monospace"
                            color: historyFrame.palette.text
                        }
                    }
                }
            }        }

        // Keypad
        GridLayout {
            id: keypad; Layout.fillWidth: true; Layout.margins: 6; columns: 5; rowSpacing: 6; columnSpacing: 8
            readonly property var keys: [
                { label:"7", type:"char", value:"7" }, { label:"8", type:"char", value:"8" }, { label:"9", type:"char", value:"9" }, { label:"+", type:"op", value:"add" }, { label:"-", type:"op", value:"sub" },
                { label:"4", type:"char", value:"4" }, { label:"5", type:"char", value:"5" }, { label:"6", type:"char", value:"6" }, { label:"×", type:"op", value:"mul" }, { label:"/", type:"op", value:"div" },
                { label:"1", type:"char", value:"1" }, { label:"2", type:"char", value:"2" }, { label:"3", type:"char", value:"3" }, { label:"ˣ√ᵧ", type:"op", value:"root" }, { label:"xʸ", type:"op", value:"pow" },
                { label:"0", type:"char", value:"0" }, { label: "DECIMAL", type: "char", value: "DECIMAL" }, { label:"⌫", type:"back", value:"" }, { label:"±", type:"fn", value:"neg" }, { label:"dup", type:"fn", value:"dup" },
                { label:"sin", type:"fn", value:"sin" }, { label:"cos", type:"fn", value:"cos" }, { label:"1/x", type:"fn", value:"inv" }, { label:"drop", type:"fn", value:"drop" }, { label:"ENTER", type:"enter", value:"" }
            ]

            function simulatePress(rawInput) {
                let targetLabel = ""
                const lower = rawInput.toLowerCase ? rawInput.toLowerCase() : rawInput
                if (rawInput === "BACK") targetLabel = "⌫"
                else if (rawInput === "ENTER") targetLabel = "ENTER"
                else if (rawInput === "." || rawInput === ",") targetLabel = "DECIMAL"
                else if (rawInput === "+") targetLabel = "+"
                else if (rawInput === "-") targetLabel = "-"
                else if (rawInput === "*" || rawInput === "×") targetLabel = "×"
                else if (rawInput === "/") targetLabel = "/"
                else if (rawInput === "^") targetLabel = "xʸ"
                else if (lower === "n") targetLabel = "±"
                else if (lower === "r") targetLabel = "ˣ√ᵧ"
                else if (lower === "s") targetLabel = "sin"
                else if (lower === "c") targetLabel = "cos"
                else if (lower === "d") targetLabel = "dup"
                else if (lower === "x") targetLabel = "drop"
                else if (lower === "i") targetLabel = "1/x"
                else if (!isNaN(parseInt(rawInput))) targetLabel = rawInput

                for (let i = 0; i < keypadRep.count; i++) {
                    const btn = keypadRep.itemAt(i)
                    const data = keypad.keys[i]
                    if (data.label === targetLabel) {
                        btn.flash()
                        if (data.label === "DECIMAL") {
                            root.keypadAction({ label: root.decimalSeparator, type: data.type, value: root.decimalSeparator })
                        } else {
                            root.keypadAction(data)
                        }
                        return true
                    }
                }
                return false
            }

            function focusFirst() { const b = keypadRep.itemAt(0); if (b) b.forceActiveFocus() }
            function relinkNav() {
                const cols = keypad.columns; const n = keypadRep.count
                for (let i = 0; i < n; i++) {
                    const b = keypadRep.itemAt(i); if (!b) continue
                    const left=(i%cols===0)?-1:(i-1), right=(i%cols===cols-1)?-1:(i+1), up=(i-cols>=0)?(i-cols):-1, down=(i+cols<n)?(i+cols):-1
                    b.KeyNavigation.left=(left>=0)?keypadRep.itemAt(left):null; b.KeyNavigation.right=(right>=0)?keypadRep.itemAt(right):null
                    b.KeyNavigation.down=(down>=0)?keypadRep.itemAt(down):null; b.KeyNavigation.up=(i<cols)?root:keypadRep.itemAt(up)
                }
            }
            Repeater { id: keypadRep; model: keypad.keys; delegate: KeyButton { key: modelData } onItemAdded: Qt.callLater(keypad.relinkNav); onItemRemoved: Qt.callLater(keypad.relinkNav) }
            Component.onCompleted: Qt.callLater(keypad.relinkNav)
        }
    }

    Popup {
        id: toast
        property string text: ""

        x: (parent.width - width)/2
        y: parent.height - height - 16
        padding: 10

        background: Rectangle {
            radius: 10
            color: toast.palette.window
            border.color: toast.palette.mid
            border.width: 1
            opacity: 0.95
        }

        contentItem: Text {
            text: toast.text
            color: toast.palette.text
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            width: Math.min(parent.width * 0.9, 360)
        }

        Timer {
            id: toastTimer
            interval: 3000
            repeat: false
            onTriggered: toast.close()
        }

        function show(msg) {
            toast.text = msg;
            toast.open();
            toastTimer.restart()
        }
    }}