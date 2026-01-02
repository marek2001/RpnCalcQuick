import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQml 2.15
import Qt5Compat.GraphicalEffects

Item {
    id: root

    // Kluczowa zmiana: root ma focus, żeby łapać klawisze globalnie
    focus: true

    // ===== Publiczne API =====
    property var stackModel: null
    property string historyText: ""
    property string decimalSeparator: "."
    property bool canUndo: false
    property bool canRedo: false

    // Aliases
    property alias inputText: displayLabel.text
    property alias inputItem: root

    property alias stackCurrentIndex: stackList.currentIndex
    readonly property int stackCount: stackList.count

    readonly property bool isStackEditing: (stackList && stackList.currentItem) ? stackList.currentItem.editing : false

    // Signals
    signal inputEnter()
    signal keypadAction(var key)
    signal pushPi()
    signal pushE()
    signal undoRequest()
    signal redoRequest()
    signal clearAllRequest()
    signal stackRemoveRequest(int index)
    signal stackMoveRequest(int delta)
    signal stackValueSet(int row, string text)

    function forceInputFocus() { root.forceActiveFocus() }
    function ensureStackVisible(idx) { stackList.positionViewAtIndex(idx, ListView.Visible) }
    function showToast(msg) { toast.show(msg) }

    // --- OBSŁUGA KLAWISZY FIZYCZNYCH ---
    Keys.onPressed: (event) => {
        if (isStackEditing) return;

        //Skróty Shift + Strzałki do przesuwania elementów na stosie
        if (event.modifiers & Qt.ShiftModifier) {
            if (event.key === Qt.Key_Up) {
                // -1 oznacza ruch w górę (zmniejszenie indeksu)
                root.stackMoveRequest(-1)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Down) {
                // +1 oznacza ruch w dół (zwiększenie indeksu)
                root.stackMoveRequest(1)
                event.accepted = true
                return
            }
        }
        
        // Nawigacja po klawiaturze (jeśli focus jest na root, strzałka w dół idzie do klawiatury)
        if (event.key === Qt.Key_Down) {
            keypad.focusFirst()
            event.accepted = true
            return
        }

        let raw = event.text
        if (event.key === Qt.Key_Backspace) raw = "BACK"
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) raw = "ENTER"
        else if (event.key === Qt.Key_Escape) raw = "CLEAR"

        if (keypad.simulatePress(raw)) {
            event.accepted = true
        }
    }

    function simulatePress(rawInput) {
        return keypad.simulatePress(rawInput)
    }

    // ===== Component: KeyButton =====
    component KeyButton: Button {
        id: btn
        property var key
        // PRZYWRÓCONO: StrongFocus, aby przyciski mogły być wybierane strzałkami
        focusPolicy: Qt.StrongFocus
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        text: key.label

        Timer { id: rT; interval: 100; onTriggered: btn.down = false }
        function flash() { btn.down = true; rT.restart() }
        onClicked: {
            root.keypadAction(key)
            // Nie oddajemy focusu do roota automatycznie, żeby nie psuć nawigacji klawiaturą
            // root.forceActiveFocus() 
        }

        // Wyjście z trybu nawigacji klawiaturą (ESC wraca do trybu wpisywania)
        Keys.onEscapePressed: { root.forceActiveFocus(); event.accepted = true }
    }

    // ===== Layout =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // EKRAN LCD
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: root.palette.base
            radius: 8
            border.color: root.palette.mid
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: root.forceActiveFocus()
            }

            Text {
                id: displayLabel
                anchors.fill: parent
                anchors.margins: 12
                text: ""
                font.family: "Monospace"
                font.pointSize: 24
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                color: root.palette.text
                elide: Text.ElideLeft
            }
        }

        // Toolbar
        RowLayout {
            Layout.fillWidth: true
            Button { text: "π"; onClicked: root.pushPi() }
            Button { text: "e"; onClicked: root.pushE() }
            Button { text: "↶"; enabled: root.canUndo; onClicked: root.undoRequest() }
            Button { text: "↷"; enabled: root.canRedo; onClicked: root.redoRequest() }
            Item { Layout.fillWidth: true }
            Button { text: "CLR"; onClicked: root.clearAllRequest() }
        }

        // SplitView
        SplitView {
            Layout.fillWidth: true; Layout.fillHeight: true
            orientation: Qt.Vertical

            // Stack
            Frame {
                SplitView.preferredHeight: parent.height * 0.7
                background: Rectangle { color: root.palette.window; border.color: root.palette.mid; border.width: 1 }
                padding: 0 // Ważne dla layoutu wewnątrz

                // PRZYWRÓCONO: RowLayout, aby zmieścić listę i panel strzałek obok siebie
                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                        ListView {
                            id: stackList
                            clip: true
                            model: root.stackModel
                            currentIndex: -1

                            delegate: Item {
                                id: rowItem
                                width: stackList.width
                                height: 40
                                property bool editing: false
                                readonly property bool isSelected: ListView.isCurrentItem

                                Rectangle {
                                    anchors.fill: parent
                                    color: rowItem.isSelected ? root.palette.highlight : root.palette.base
                                }

                                Rectangle {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1
                                    color: root.palette.mid
                                    visible: !rowItem.isSelected
                                }

                                MouseArea {
                                    anchors.left: parent.left; anchors.right: removeBtn.left
                                    anchors.top: parent.top; anchors.bottom: parent.bottom
                                    enabled: !rowItem.editing
                                    onClicked: { stackList.currentIndex = index; root.forceActiveFocus() }
                                    onDoubleClicked: {
                                        stackList.currentIndex = index
                                        rowItem.editing = true
                                        editField.text = model.value
                                        editField.forceActiveFocus()
                                        editField.selectAll()
                                    }
                                }

                                Text {
                                    id: idxText
                                    anchors.left: parent.left; anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (index + 1).toString()
                                    color: rowItem.isSelected ? root.palette.highlightedText : root.palette.text
                                    font.family: "Monospace"
                                }

                                Rectangle {
                                    id: vSep
                                    width: 1
                                    anchors.left: idxText.right; anchors.leftMargin: 12
                                    anchors.top: parent.top; anchors.bottom: parent.bottom
                                    anchors.topMargin: 4; anchors.bottomMargin: 4
                                    color: rowItem.isSelected ? root.palette.highlightedText : root.palette.mid
                                    opacity: 0.5
                                }

                                Text {
                                    anchors.left: vSep.right; anchors.leftMargin: 12
                                    anchors.right: removeBtn.left; anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.value
                                    visible: !rowItem.editing
                                    color: rowItem.isSelected ? root.palette.highlightedText : root.palette.text
                                    font.family: "Monospace"
                                    elide: Text.ElideLeft
                                }

                                TextField {
                                    id: editField
                                    anchors.left: vSep.right; anchors.leftMargin: 12
                                    anchors.right: removeBtn.left; anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: rowItem.editing
                                    font.family: "Monospace"
                                    function commit() {
                                        if (root.stackModel && root.stackModel.setValueAt(index, text)) {
                                            rowItem.editing = false
                                            root.forceActiveFocus()
                                        } else {
                                            toast.show("Błąd liczby")
                                            forceActiveFocus()
                                        }
                                    }
                                    Keys.onReturnPressed: commit()
                                    Keys.onEnterPressed: commit()
                                    Keys.onEscapePressed: { rowItem.editing = false; root.forceActiveFocus() }
                                    onEditingFinished: if (rowItem.editing) commit()
                                }

                                ToolButton {
                                    id: removeBtn
                                    anchors.right: parent.right; anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "✕"
                                    onClicked: root.stackRemoveRequest(index)
                                }
                            }
                        }
                    }

                    // PRZYWRÓCONO: Panel boczny ze strzałkami
                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.fillHeight: true
                        color: root.palette.window

                        // Linia oddzielająca od listy
                        Rectangle {
                            width: 1; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                            color: root.palette.mid
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            ToolButton {
                                text: "▲"
                                Layout.fillWidth: true
                                enabled: stackList.currentIndex > 0
                                onClicked: root.stackMoveRequest(-1)
                            }
                            ToolButton {
                                text: "▼"
                                Layout.fillWidth: true
                                enabled: stackList.currentIndex >= 0 && stackList.currentIndex < stackList.count - 1
                                onClicked: root.stackMoveRequest(+1)
                            }
                            Item { Layout.fillHeight: true } // Wypełniacz
                        }
                    }
                }
            }

            // History
            Frame {
                SplitView.preferredHeight: parent.height * 0.3
                background: Rectangle { color: root.palette.window; border.color: root.palette.mid; border.width: 1 }

                ScrollView {
                    anchors.fill: parent
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                    TextArea {
                        text: root.historyText
                        readOnly: true
                        font.family: "Monospace"
                        color: root.palette.text
                        background: null
                    }
                }
            }
        }

        // Keypad
        GridLayout {
            id: keypad
            Layout.fillWidth: true; Layout.margins: 6
            columns: 5; rowSpacing: 6; columnSpacing: 8

            readonly property var keys: [
                { label:"7", type:"char", value:"7" }, { label:"8", type:"char", value:"8" }, { label:"9", type:"char", value:"9" },
                { label:"+", type:"op", value:"add" }, { label:"-", type:"op", value:"sub" },

                { label:"4", type:"char", value:"4" }, { label:"5", type:"char", value:"5" }, { label:"6", type:"char", value:"6" },
                { label:"×", type:"op", value:"mul" }, { label:"/", type:"op", value:"div" },

                { label:"1", type:"char", value:"1" }, { label:"2", type:"char", value:"2" }, { label:"3", type:"char", value:"3" },
                { label:"ˣ√ᵧ", type:"op", value:"root" }, { label:"xʸ", type:"op", value:"pow" },

                { label:"0", type:"char", value:"0" }, { label: root.decimalSeparator, type:"char", value: root.decimalSeparator },
                { label:"⌫", type:"back", value:"" }, { label:"±", type:"fn", value:"neg" }, { label:"dup", type:"fn", value:"dup" },

                { label:"sin", type:"fn", value:"sin" }, { label:"cos", type:"fn", value:"cos" },
                { label:"1/x", type:"fn", value:"inv" }, { label:"drop", type:"fn", value:"drop" },
                { label:"ENTER", type:"enter", value:"" }
            ]

            function simulatePress(rawInput) {
                let targetLabel = ""
                const lower = rawInput.toLowerCase ? rawInput.toLowerCase() : rawInput

                if (rawInput === "BACK") targetLabel = "⌫"
                else if (rawInput === "ENTER") targetLabel = "ENTER"
                else if (rawInput === "." || rawInput === ",") targetLabel = root.decimalSeparator
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
                        root.keypadAction(data)
                        return true
                    }
                }
                return false
            }

            // PRZYWRÓCONO: Funkcja do ustawienia fokusu na pierwszy klawisz
            function focusFirst() {
                const b = keypadRep.itemAt(0)
                if (b) b.forceActiveFocus()
            }

            // PRZYWRÓCONO: Logika nawigacji strzałkami
            function relinkNav() {
                const cols = keypad.columns
                const n = keypadRep.count
                for (let i = 0; i < n; i++) {
                    const b = keypadRep.itemAt(i)
                    if (!b) continue
                    const leftIndex  = (i % cols === 0) ? -1 : (i - 1)
                    const rightIndex = (i % cols === cols - 1) ? -1 : (i + 1)
                    const upIndex    = (i - cols >= 0) ? (i - cols) : -1
                    const downIndex  = (i + cols < n) ? (i + cols) : -1

                    b.KeyNavigation.left  = (leftIndex  >= 0) ? keypadRep.itemAt(leftIndex)  : null
                    b.KeyNavigation.right = (rightIndex >= 0) ? keypadRep.itemAt(rightIndex) : null
                    b.KeyNavigation.down  = (downIndex  >= 0) ? keypadRep.itemAt(downIndex)  : null

                    // Jeśli jesteśmy w górnym rzędzie, strzałka w górę wraca do inputu (root)
                    if (i < cols) b.KeyNavigation.up = root
                    else          b.KeyNavigation.up = keypadRep.itemAt(upIndex)
                }
            }

            Repeater {
                id: keypadRep
                model: keypad.keys
                delegate: KeyButton { key: modelData }
                // PRZYWRÓCONO: Aktualizacja nawigacji po załadowaniu
                onItemAdded: Qt.callLater(keypad.relinkNav)
                onItemRemoved: Qt.callLater(keypad.relinkNav)
            }
            Component.onCompleted: Qt.callLater(keypad.relinkNav)
        }
    }

    Popup {
        id: toast
        x: (parent.width - width)/2; y: parent.height - height - 20
        padding: 10
        background: Rectangle { color: "#333"; radius: 10; opacity: 0.9 }
        contentItem: Text { id: tText; color: "white" }
        function show(msg) { tText.text = msg; open(); tTimer.restart() }
        Timer { id: tTimer; interval: 3000; onTriggered: toast.close() }
    }
}