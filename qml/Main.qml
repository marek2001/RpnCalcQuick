import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import Qt.labs.platform as Native
import RpnCalc.Backend 1.0

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

    // Systemowy kolor akcentu (KDE/Qt style -> highlight)
    readonly property color accentColor: win.palette.highlight


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

            Native.MenuItemGroup { id: precGroup; exclusive: true }

            Instantiator {
                model: 16 // 0..15
                delegate: Native.MenuItem {
                    text: model.index.toString()
                    checkable: true
                    checked: rpn.precision === model.index
                    group: precGroup
                    onTriggered: rpn.precision = model.index
                }
                onObjectAdded: (index, object) => precisionMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => precisionMenu.removeItem(object)
            }
        }

        Native.Menu {
            title: "History"
            Native.MenuItem {
                text: "Clear history"
                onTriggered: rpn.clearHistory()
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
    Shortcut { sequence: "Backspace"; onActivated: backspace() }

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
                if (event.key === Qt.Key_Backspace) return
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) return

                let handled = true

                switch (event.key) {
                    case Qt.Key_Plus:     op(rpn.add); break
                    case Qt.Key_Minus:    op(rpn.sub); break
                    case Qt.Key_Asterisk: op(rpn.mul); break
                    case Qt.Key_Slash:    op(rpn.div); break
                    default: handled = false; break
                }

                if (!handled) {
                    handled = true
                    switch (event.text) {
                        case "+": op(rpn.add); break
                        case "-": op(rpn.sub); break
                        case "*": op(rpn.mul); break
                        case "/": op(rpn.div); break
                        case "^": op(rpn.pow); break
                        default: handled = false; break
                    }
                }

                if (handled) {
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

                        // żeby overlay suwak nie nachodził na X
                        property int vbarWidth: 10

                        // pokaż suwak na scroll i schowaj po chwili
                        property bool showStackBar: false

                        Timer {
                            id: stackBarTimer
                            interval: 700
                            repeat: false
                            onTriggered: stackList.showStackBar = false
                        }

                        onContentYChanged: {
                            stackList.showStackBar = true
                            stackBarTimer.restart()
                        }
                        onMovementStarted: {
                            stackList.showStackBar = true
                            stackBarTimer.restart()
                        }
                        onMovementEnded: stackBarTimer.restart()

                        // ===== SYSTEMOWY OVERLAY SCROLLBAR (akcent) =====
                        ScrollBar.vertical: ScrollBar {
                            id: stackVBar
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            z: 100

                            width: stackList.vbarWidth
                            padding: 2

                            readonly property bool needed: stackList.contentHeight > stackList.height + 1
                            visible: needed

                            opacity: (needed && (stackList.showStackBar || pressed || hovered)) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            background: Item {}
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: width / 2
                                color: win.accentColor
                                opacity: 0.9
                            }
                        }

                        delegate: Item {
                            id: rowItem
                            width: stackList.width
                            height: stackList.rowHeight
                            property bool editing: false

                            readonly property bool isSelected: ListView.isCurrentItem

                            Rectangle {
                                anchors.fill: parent
                                color: rowItem.isSelected ? stackFrame.palette.highlight : stackFrame.palette.base
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: stackFrame.palette.mid
                            }

                            MouseArea {
                                anchors.left: parent.left
                                anchors.right: removeBtn.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                visible: !rowItem.editing
                                onClicked: {
                                    stackList.currentIndex = index
                                    input.forceActiveFocus()
                                }
                            }

                            Text {
                                id: idxText
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: (index + 1).toString()
                                color: rowItem.isSelected ? stackFrame.palette.highlightedText : stackFrame.palette.text
                                font.family: "Monospace"
                            }

                            Rectangle {
                                id: vSep
                                width: 1
                                anchors.left: idxText.right
                                anchors.leftMargin: 12
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 4
                                anchors.bottomMargin: 4
                                color: rowItem.isSelected ? stackFrame.palette.highlightedText : stackFrame.palette.mid
                                opacity: 0.5
                            }

                            Text {
                                id: valueText
                                anchors.left: vSep.right
                                anchors.leftMargin: 12
                                anchors.right: removeBtn.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.value
                                visible: !rowItem.editing
                                color: rowItem.isSelected ? stackFrame.palette.highlightedText : stackFrame.palette.text
                                font.family: "Monospace"
                                elide: Text.ElideLeft
                            }

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

                            TextField {
                                id: editField
                                anchors.left: vSep.right
                                anchors.leftMargin: 12
                                anchors.right: removeBtn.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                height: 30
                                visible: rowItem.editing
                                font.family: "Monospace"
                                selectByMouse: true
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

                                onEditingFinished: {
                                    if (rowItem.editing) commit()
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                visible: rowItem.editing
                                z: 999
                                onClicked: editField.commit()
                            }

                            ToolButton {
                                id: removeBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 6 + stackList.vbarWidth
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
                        ToolButton { text: "Clear"; onClicked: rpn.clearHistory() }
                    }

                    // ===== WERSJA "SYSTEMOWA": Flickable + TextEdit (pewne scrollbary) =====
                    Flickable {
                        id: historyFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.AutoFlickDirection

                        // content z TextEdit
                        contentWidth: historyText.implicitWidth
                        contentHeight: historyText.implicitHeight

                        // pokaż suwaki po scrollu i schowaj po chwili
                        property bool showHistBars: false

                        Timer {
                            id: histBarTimer
                            interval: 700
                            repeat: false
                            onTriggered: historyFlick.showHistBars = false
                        }

                        onContentYChanged: {
                            historyFlick.showHistBars = true
                            histBarTimer.restart()
                        }
                        onContentXChanged: {
                            historyFlick.showHistBars = true
                            histBarTimer.restart()
                        }
                        onMovementStarted: {
                            historyFlick.showHistBars = true
                            histBarTimer.restart()
                        }
                        onMovementEnded: histBarTimer.restart()

                        // pionowy overlay
                        ScrollBar.vertical: ScrollBar {
                            id: histVBar
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            z: 100

                            width: 10
                            padding: 2

                            readonly property bool needed: historyFlick.contentHeight > historyFlick.height + 1
                            visible: needed

                            opacity: (needed && (historyFlick.showHistBars || pressed || hovered)) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            background: Item {}
                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: width / 2
                                color: win.accentColor
                                opacity: 0.9
                            }
                        }

                        // poziomy overlay
                        ScrollBar.horizontal: ScrollBar {
                            id: histHBar
                            policy: ScrollBar.AsNeeded
                            hoverEnabled: true
                            z: 100

                            height: 10
                            padding: 2

                            readonly property bool needed: historyFlick.contentWidth > historyFlick.width + 1
                            visible: needed

                            opacity: (needed && (historyFlick.showHistBars || pressed || hovered)) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            background: Item {}
                            contentItem: Rectangle {
                                implicitHeight: 6
                                radius: height / 2
                                color: win.accentColor
                                opacity: 0.9
                            }
                        }

                        TextEdit {
                            id: historyText
                            x: 0
                            y: 0

                            text: rpn.historyText
                            readOnly: true
                            selectByMouse: true

                            // brak zawijania, żeby poziomy scroll miał sens
                            wrapMode: TextEdit.NoWrap

                            font.family: "Monospace"
                            color: historyFrame.palette.text

                            // ważne: niech tekst ma co najmniej szerokość viewportu,
                            // ale może być szerszy (wtedy poziomy scroll działa)
                            width: Math.max(historyFlick.width, implicitWidth)
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
