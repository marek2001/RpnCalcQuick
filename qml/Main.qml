import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RpnCalc.Backend 1.0
import Qt.labs.platform as Native
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml // <--- DODAJ TO dla Instantiator
import RpnCalc.Backend 1.0
import Qt.labs.platform as Native

ApplicationWindow {
    id: win
    RpnEngine { id: rpn }

    width: 500
    height: 720
    visible: true
    title: "RPN Calculator (Qt Quick)"
    minimumWidth: 500
    minimumHeight: 640
    maximumWidth: 800
    maximumHeight: 1200

    // ===== Global Menu (KDE Plasma) =====
    Native.MenuBar {
        id: appMenu
        window: win

        Native.Menu {
            title: "Notation"
            Native.MenuItemGroup { id: fmtGroup; exclusive: true }

            Native.MenuItem {
                text: "Scientific"
                checkable: true
                checked: rpn.formatMode === 0
                group: fmtGroup
                onTriggered: rpn.formatMode = 0
            }
            Native.MenuItem {
                text: "Engineering"
                checkable: true
                checked: rpn.formatMode === 1
                group: fmtGroup
                onTriggered: rpn.formatMode = 1
            }
            Native.MenuItem {
                text: "Simple"
                checkable: true
                checked: rpn.formatMode === 2
                group: fmtGroup
                onTriggered: rpn.formatMode = 2
            }
        }

        Native.Menu {
            id: precisionMenu
            title: "Precision"

            Native.MenuItemGroup {
                id: precGroup
                exclusive: true
            }

            // Instantiator dynamicznie tworzy obiekty MenuItem
            Instantiator {
                model: 16 // Generuje liczby od 0 do 15

                delegate: Native.MenuItem {
                    text: model.index.toString()
                    checkable: true
                    checked: rpn.precision === model.index
                    group: precGroup
                    onTriggered: rpn.precision = model.index
                }

                // Ważne: musimy ręcznie dodać stworzone elementy do menu
                onObjectAdded: (index, object) => precisionMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => precisionMenu.removeItem(object)
            }
        }
        Native.Menu {
            title: "History"
            Native.MenuItem {
                text: "Clear history"
                onTriggered: rpn.historyModel.clear()
            }
        }
    }

    // ===== helpers =====
    function autoEnterIfNeeded() {
        const t = input.text.trim()
        if (t.length > 0) {
            if (rpn.enter(t)) input.text = ""
        }
    }

    function op(fn) {
        autoEnterIfNeeded()
        fn()
    }

    function appendChar(s) {
        input.text = input.text + s
        input.forceActiveFocus()
    }

    function backspace() {
        if (input.text.length > 0)
            input.text = input.text.slice(0, input.text.length - 1)
        input.forceActiveFocus()
    }

    function doEnter() {
        if (rpn.enter(input.text))
            input.text = ""
        input.forceActiveFocus()
    }

    function removeStackAt(row) {
        if (row < 0 || row >= stackList.count) return
        const cur = stackList.currentIndex
        rpn.stackModel.removeAt(row)

        if (stackList.count === 0) {
            stackList.currentIndex = -1
            return
        }

        if (cur === -1) stackList.currentIndex = 0
        else if (cur > row) stackList.currentIndex = cur - 1
        else if (cur === row) stackList.currentIndex = Math.min(row, stackList.count - 1)

        stackList.positionViewAtIndex(stackList.currentIndex, ListView.Visible)
        input.forceActiveFocus()
    }

    // ===== shortcuts =====
    Shortcut {
        sequences: [ StandardKey.InsertParagraphSeparator, StandardKey.InsertLineSeparator ]
        onActivated: doEnter()
    }
    Shortcut { sequence: "Space"; onActivated: doEnter() }
    Shortcut {
        sequence: "Backspace"
        onActivated: backspace()
    }

    // --- OPERATORY BINARNE ---
    Shortcut { sequence: "+"; onActivated: op(rpn.add) }
    Shortcut { sequence: "-"; onActivated: op(rpn.sub) }
    Shortcut { sequence: "*"; onActivated: op(rpn.mul) }
    Shortcut { sequence: "/"; onActivated: op(rpn.div) }
    Shortcut { sequence: "^"; onActivated: op(rpn.pow) }

    // zamienniki z klawiatury numerycznej
    Shortcut { sequence: "Multiply"; onActivated: op(rpn.mul) }
    Shortcut { sequence: "Divide";   onActivated: op(rpn.div) }
    Shortcut { sequence: "Add";      onActivated: op(rpn.add) }
    Shortcut { sequence: "Subtract"; onActivated: op(rpn.sub) }

    Shortcut { sequence: "S"; onActivated: op(rpn.sin) }
    Shortcut { sequence: "C"; onActivated: op(rpn.cos) }
    Shortcut { sequence: "N"; onActivated: op(rpn.neg) }
    Shortcut { sequence: "D"; onActivated: op(rpn.dup) }
    Shortcut { sequence: "X"; onActivated: op(rpn.drop) }
    Shortcut { sequence: "R"; onActivated: op(rpn.sqrt) }
    Shortcut { sequence: "W"; onActivated: op(rpn.swap) }


    // ===== toast =====
    Popup {
        id: toast
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        padding: 10
        property string text: ""

        x: (parent.width - width) / 2
        y: parent.height - height - 16

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
            width: Math.min(parent.width * 0.9, 360)
        }

        Timer {
            id: toastTimer
            interval: 3000
            repeat: false
            onTriggered: toast.close()
        }

        function show(msg) {
            toast.text = msg
            toast.open()
            toastTimer.restart()
        }
    }

    Connections {
        target: rpn
        function onErrorOccurred(message) { toast.show(message) }
    }

    // ===== layout =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        TextField {
            id: input
            Layout.fillWidth: true
            placeholderText: "Wpisz liczbę, Enter → push"
            font.family: "Monospace"
            font.pointSize: 16
            horizontalAlignment: Text.AlignRight
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            focus: true

            Keys.onReturnPressed: doEnter()
            Keys.onEnterPressed: doEnter()

            Keys.onPressed: (event) => {
                // pozwól normalnie działać Backspace
                if (event.key === Qt.Key_Backspace)
                    return

                // Enter obsługujesz wyżej
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    return

                let handled = true

                // najpierw klawisze z numpada i „key codes”
                switch (event.key) {
                    case Qt.Key_Plus:
                        op(rpn.add); break
                    case Qt.Key_Minus:
                        op(rpn.sub); break
                    case Qt.Key_Asterisk:
                        op(rpn.mul); break
                    case Qt.Key_Slash:
                        op(rpn.div); break
                    default:
                        handled = false
                        break
                }

                // jeśli nie złapaliśmy po key, spróbuj po tekście (zwykła klawiatura)
                if (!handled) {
                    handled = true
                    switch (event.text) {
                        case "+": op(rpn.add); break
                        case "-": op(rpn.sub); break
                        case "*": op(rpn.mul); break
                        case "/": op(rpn.div); break
                        case "^": op(rpn.pow); break
                        default:
                            handled = false
                            break
                    }
                }

                if (handled) {
                    // nie wpisuj operatora do pola
                    event.accepted = true
                    input.forceActiveFocus()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button { text: "π"; onClicked: rpn.pushPi() }
            Button { text: "e"; onClicked: rpn.pushE() }

            Item { Layout.fillWidth: true }

            Button {
                text: "CLR"
                onClicked: {
                    input.text = ""
                    rpn.clearAll()
                    input.forceActiveFocus()
                }
            }
        }

        // ===== stack + history =====
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical

            // ---- STACK ----
            Frame {
                id: stackFrame
                padding: 0

                background: Rectangle {
                    radius: 10
                    color: stackFrame.palette.window
                    border.color: stackFrame.palette.mid
                    border.width: 1
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    ListView {
                        id: stackList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        model: rpn.stackModel
                        currentIndex: -1
                        property int rowHeight: 40

                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: 60

                        delegate: Item {
                            id: rowItem
                            width: stackList.width
                            height: stackList.rowHeight
                            property bool editing: false
                            
                            Rectangle { anchors.fill: parent; color: stackFrame.palette.base }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: stackFrame.palette.mid
                            }

                            // klik wiersza (zaznacz), ale NIE przykrywa pola edycji ani X
                            MouseArea {
                                anchors.left: parent.left
                                anchors.right: removeBtn.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                onClicked: {
                                    stackList.currentIndex = index
                                    input.forceActiveFocus()
                                }
                            }

                            // Właściwość pomocnicza sprawdzająca czy ten wiersz jest wybrany
                            readonly property bool isSelected: ListView.isCurrentItem

                            // TŁO WIERSZA
                            Rectangle {
                                anchors.fill: parent
                                // Jeśli wybrany -> kolor podświetlenia (highlight), jeśli nie -> kolor bazowy (base)
                                color: rowItem.isSelected ? stackFrame.palette.highlight : stackFrame.palette.base

                                // Opcjonalnie: lekka przezroczystość, jeśli kolor podświetlenia jest zbyt intensywny
                                // opacity: rowItem.isSelected ? 0.7 : 1.0 
                            }

                            // 1. NUMER INDEKSU
                            Text {
                                id: idxText
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: (index + 1).toString()

                                // Pamiętaj o kolorze z poprzedniego kroku (podświetlenie)
                                color: rowItem.isSelected ? stackFrame.palette.highlightedText : stackFrame.palette.text
                                font.family: "Monospace"
                            }

                            // 2. NOWOŚĆ: PIONOWA LINIA ROZDZIELAJĄCA
                            Rectangle {
                                id: vSep
                                width: 1

                                // Ustawiamy linię obok indeksu z odstępem
                                anchors.left: idxText.right
                                anchors.leftMargin: 12

                                // Rozciągamy linię góra-dół z małym marginesem (żeby nie dotykała krawędzi)
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 4
                                anchors.bottomMargin: 4

                                // Kolor linii (dopasowany do ramki, lub jaśniejszy na podświetleniu)
                                color: rowItem.isSelected ? stackFrame.palette.highlightedText : stackFrame.palette.mid
                                opacity: 0.5 // Lekka przezroczystość, żeby linia nie była zbyt agresywna
                            }

                            // 3. WARTOŚĆ (zaktualizowane zakotwiczenie)
                            Text {
                                id: valueText

                                // ZMIANA: Teraz przyklejamy się do linii (vSep), a nie do idxText
                                anchors.left: vSep.right
                                anchors.leftMargin: 12

                                anchors.right: removeBtn.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.value
                                visible: !rowItem.editing

                                // Kolor z poprzedniego kroku
                                color: rowItem.isSelected ? stackFrame.palette.highlightedText : stackFrame.palette.text
                                font.family: "Monospace"
                                elide: Text.ElideLeft
                            }
                            // Dwuklik na wartość -> edycja
                            MouseArea {
                                anchors.fill: valueText
                                enabled: !rowItem.editing
                                onDoubleClicked: {
                                    stackList.currentIndex = index
                                    rowItem.editing = true
                                    editField.text = model.value
                                    editField.forceActiveFocus()
                                    editField.selectAll()
                                }
                            }

                            // WARTOŚĆ (tryb edycji)
                            TextField {
                                id: editField
                                anchors.left: idxText.right
                                anchors.leftMargin: 12
                                anchors.right: removeBtn.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                height: 30
                                visible: rowItem.editing
                                font.family: "Monospace"
                                selectByMouse: true

                                // WAŻNE: przechwytuj Enter zanim zrobi to globalny Shortcut
                                Keys.priority: Keys.BeforeItem

                                function commit() {
                                    if (rpn.stackModel.setValueAt(index, text)) {
                                        rowItem.editing = false
                                        input.forceActiveFocus()
                                    } else {
                                        toast.show("Nieprawidłowa liczba")
                                        forceActiveFocus()
                                        selectAll()
                                    }
                                }

                                Keys.onReturnPressed: commit()
                                Keys.onEnterPressed: commit()

                                Keys.onEscapePressed: {
                                    rowItem.editing = false
                                    input.forceActiveFocus()
                                }

                                // Klik poza pole / utrata fokusu -> zakończ edycję (tu: zapis)
                                onEditingFinished: {
                                    if (rowItem.editing) commit()
                                }
                            }
                            // Klik w wiersz podczas edycji -> zapis (lub możesz tu dać anuluj)
                            MouseArea {
                                anchors.fill: parent
                                visible: rowItem.editing
                                z: 999
                                onClicked: editField.commit()
                                // jeśli wolisz anulować:
                                // onClicked: { rowItem.editing = false; input.forceActiveFocus() }
                            }

                            // X usuwa
                            ToolButton {
                                id: removeBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34
                                height: 34
                                text: "✕"
                                onClicked: win.removeStackAt(index)
                            }
                        }
                    }

                    // arrows: move selected item
                    Frame {
                        id: arrows
                        Layout.preferredWidth: 48
                        Layout.fillHeight: true
                        padding: 6

                        background: Rectangle {
                            color: arrows.palette.window
                            border.color: arrows.palette.mid
                            border.width: 1
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            ToolButton {
                                text: "▲"
                                Layout.fillWidth: true
                                enabled: stackList.currentIndex > 0
                                onClicked: {
                                    const i = stackList.currentIndex
                                    if (rpn.stackModel.moveUp(i)) {
                                        stackList.currentIndex = i - 1
                                        stackList.positionViewAtIndex(stackList.currentIndex, ListView.Visible)
                                    }
                                }
                            }

                            ToolButton {
                                text: "▼"
                                Layout.fillWidth: true
                                enabled: stackList.currentIndex >= 0 && stackList.currentIndex < stackList.count - 1
                                onClicked: {
                                    const i = stackList.currentIndex
                                    if (rpn.stackModel.moveDown(i)) {
                                        stackList.currentIndex = i + 1
                                        stackList.positionViewAtIndex(stackList.currentIndex, ListView.Visible)
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }

            // ---- HISTORY ----
            // ---- HISTORY (TextBox) ----
            Frame {
                id: historyFrame
                padding: 6

                background: Rectangle {
                    radius: 10
                    color: historyFrame.palette.window
                    border.color: historyFrame.palette.mid
                    border.width: 1
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true

                        Label { text: "History"; opacity: 0.85 }
                        Item { Layout.fillWidth: true }

                        ToolButton {
                            text: "Clear"
                            onClicked: rpn.clearHistory()
                        }
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        TextArea {
                            id: historyBox
                            text: rpn.historyText
                            readOnly: true
                            wrapMode: Text.NoWrap
                            selectByMouse: true
                            persistentSelection: true
                            font.family: "Monospace"
                            background: null
                        }
                    }
                }
            }
        }

        // ===== keypad =====
        GridLayout {
            Layout.fillWidth: true
            Layout.margins: 6
            columns: 5
            rowSpacing: 8
            columnSpacing: 8

            Button { text: "7"; onClicked: appendChar("7") }
            Button { text: "8"; onClicked: appendChar("8") }
            Button { text: "9"; onClicked: appendChar("9") }
            Button { text: "+"; onClicked: op(rpn.add) }
            Button { text: "-"; onClicked: op(rpn.sub) }

            Button { text: "4"; onClicked: appendChar("4") }
            Button { text: "5"; onClicked: appendChar("5") }
            Button { text: "6"; onClicked: appendChar("6") }
            Button { text: "×"; onClicked: op(rpn.mul) }
            Button { text: "/"; onClicked: op(rpn.div) }

            Button { text: "1"; onClicked: appendChar("1") }
            Button { text: "2"; onClicked: appendChar("2") }
            Button { text: "3"; onClicked: appendChar("3") }
            Button { text: "sqrt"; onClicked: op(rpn.sqrt) }
            Button { text: "xʸ"; onClicked: op(rpn.pow) }

            Button { text: "0"; onClicked: appendChar("0") }
            Button { text: "."; onClicked: appendChar(".") }
            Button { text: "⌫"; onClicked: backspace() }
            Button { text: "±"; onClicked: op(rpn.neg) }
            Button { text: "dup"; onClicked: op(rpn.dup) }

            Button { text: "sin"; onClicked: op(rpn.sin) }
            Button { text: "cos"; onClicked: op(rpn.cos) }
            Button { text: "swap"; onClicked: op(rpn.swap) }
            Button { text: "drop"; onClicked: op(rpn.drop) }
            Button { text: "ENTER"; onClicked: doEnter() }
        }

        Label {
            Layout.fillWidth: true
            text: "Uwaga: sin/cos liczą w radianach. Klik na element stosu zaznacza go. X usuwa. Strzałki przesuwają wybrany element."
            wrapMode: Text.Wrap
            opacity: 0.75
        }
    }
}
