import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQml 2.15
import Qt.labs.platform as Native
import Qt5Compat.GraphicalEffects
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

    // ===== style/constants =====
    readonly property int cornerRadius: 12
    readonly property int splitHandleH: 8
    readonly property int stackMinH: 200
    readonly property int historyMinH: 140

    readonly property color accentColor: win.palette.highlight

    // true when inline stack editField is active (so we don't steal keys from it)
    readonly property bool stackEditing: stackList && stackList.currentItem && stackList.currentItem.editing
    // allow "typing into input" even if focus is elsewhere (keypad/list/etc.)
    readonly property bool allowGlobalTyping: !input.activeFocus && !stackEditing

    // ===== helpers =====
    function keepFocus(doWork) {
        const prev = win.activeFocusItem
        doWork()
        if (prev && prev !== input && win.activeFocusItem === input)
            prev.forceActiveFocus()
    }

    function autoEnterIfNeeded() {
        const t = input.text.trim()
        if (t.length > 0 && rpn.enter(t))
            input.text = ""
    }

    function doEnter() {
        keepFocus(() => {
            if (rpn.enter(input.text))
                input.text = ""
        })
    }

    function op(fn) {
        keepFocus(() => {
            autoEnterIfNeeded()
            fn()
        })
    }

    function appendChar(s) {
        keepFocus(() => { input.text = input.text + s })
    }

    function backspace() {
        keepFocus(() => {
            if (input.text.length > 0)
                input.text = input.text.slice(0, input.text.length - 1)
        })
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

    function moveSelectedStack(delta) {
        const i = stackList.currentIndex
        if (i < 0) return

        if (delta < 0 && i > 0) {
            if (rpn.stackModel.moveUp(i)) {
                stackList.currentIndex = i - 1
                stackList.positionViewAtIndex(stackList.currentIndex, ListView.Visible)
            }
        } else if (delta > 0 && i < stackList.count - 1) {
            if (rpn.stackModel.moveDown(i)) {
                stackList.currentIndex = i + 1
                stackList.positionViewAtIndex(stackList.currentIndex, ListView.Visible)
            }
        }
    }

    // ===== Global Menu =====
    Native.MenuBar {
        id: appMenu
        window: win

        Native.Menu {
            title: "Notation"
            Native.MenuItemGroup { id: fmtGroup; exclusive: true }

            Native.MenuItem { text: "Scientific";  checkable: true; checked: rpn.formatMode === 0; group: fmtGroup; onTriggered: rpn.formatMode = 0 }
            Native.MenuItem { text: "Engineering"; checkable: true; checked: rpn.formatMode === 1; group: fmtGroup; onTriggered: rpn.formatMode = 1 }
            Native.MenuItem { text: "Simple";      checkable: true; checked: rpn.formatMode === 2; group: fmtGroup; onTriggered: rpn.formatMode = 2 }
        }

        Native.Menu {
            id: precisionMenu
            title: "Precision"
            Native.MenuItemGroup { id: precGroup; exclusive: true }

            // Precision range: 2..15
            Instantiator {
                model: 14   // 14 values -> 2..15
                delegate: Native.MenuItem {
                    readonly property int prec: model.index + 2

                    text: prec.toString()
                    checkable: true
                    checked: rpn.precision === prec
                    group: precGroup
                    onTriggered: rpn.precision = prec
                }

                onObjectAdded: (index, object) => precisionMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => precisionMenu.removeItem(object)
            }
        }

        Native.Menu {
            title: "History"
            Native.MenuItem { text: "Clear history"; onTriggered: rpn.clearHistory() }
        }

        Native.Menu {
            title: "Edit"
            Native.MenuItem { text: "Undo"; shortcut: "Ctrl+Z";        enabled: rpn.canUndo; onTriggered: rpn.undo() }
            Native.MenuItem { text: "Redo"; shortcut: StandardKey.Redo; enabled: rpn.canRedo; onTriggered: rpn.redo() }
        }
    }

    // ===== shortcuts =====
    Shortcut { sequence: "Return"; context: Qt.ApplicationShortcut; enabled: !win.stackEditing; onActivated: win.doEnter() }
    Shortcut { sequence: "Enter";  context: Qt.ApplicationShortcut; enabled: !win.stackEditing; onActivated: win.doEnter() }

    Shortcut { sequence: "Backspace"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping; onActivated: win.backspace() }

    Shortcut { sequence: "Shift+Up";   context: Qt.ApplicationShortcut; enabled: !win.stackEditing && stackList.currentIndex > 0; onActivated: win.moveSelectedStack(-1) }
    Shortcut { sequence: "Shift+Down"; context: Qt.ApplicationShortcut; enabled: !win.stackEditing && stackList.currentIndex >= 0 && stackList.currentIndex < stackList.count - 1; onActivated: win.moveSelectedStack(+1) }

    Repeater {
        model: 10
        delegate: Item {
            visible: false
            Shortcut {
                sequence: modelData.toString()
                context: Qt.ApplicationShortcut
                enabled: win.allowGlobalTyping
                onActivated: win.appendChar(modelData.toString())
            }
        }
    }
    Item { visible: false; Shortcut { sequence: "."; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping; onActivated: win.appendChar(".") } }
    Item { visible: false; Shortcut { sequence: ","; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping; onActivated: win.appendChar(".") } }

    Shortcut { sequence: StandardKey.Undo; onActivated: rpn.undo() }
    Shortcut { sequence: StandardKey.Redo; onActivated: rpn.redo() }

    Shortcut { sequence: "+"; onActivated: op(rpn.add) }
    Shortcut { sequence: "-"; onActivated: op(rpn.sub) }
    Shortcut { sequence: "*"; onActivated: op(rpn.mul) }
    Shortcut { sequence: "/"; onActivated: op(rpn.div) }
    Shortcut { sequence: "^"; onActivated: op(rpn.pow) }

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

        Timer { id: toastTimer; interval: 3000; repeat: false; onTriggered: toast.close() }

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

    // ===== reusable inline component: keypad button =====
    component KeyButton: Button {
        property var key
        focusPolicy: Qt.StrongFocus

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        Layout.minimumHeight: 20
        Layout.maximumHeight: 34

        text: key.label

        onClicked: keypad.trigger(key)

        // prevent focused button from "clicking" on Enter: Enter always pushes input
        Keys.onReturnPressed: function(e) { win.doEnter(); e.accepted = true }
        Keys.onEnterPressed:  function(e) { win.doEnter(); e.accepted = true }
        Keys.onEscapePressed: function(e) { input.forceActiveFocus(); e.accepted = true }
    }

    // ===== layout =====
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        TextField {
            id: input
            Layout.fillWidth: true
            font.family: "Monospace"
            font.pointSize: 16
            horizontalAlignment: Text.AlignRight
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            focus: true

            Keys.onDownPressed: function(e) { keypad.focusFirst(); e.accepted = true }

            Keys.onPressed: function(e) {
                if (e.key === Qt.Key_Backspace) return
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) return

                let handled = true
                switch (e.key) {
                    case Qt.Key_Plus:     op(rpn.add); break
                    case Qt.Key_Minus:    op(rpn.sub); break
                    case Qt.Key_Asterisk: op(rpn.mul); break
                    case Qt.Key_Slash:    op(rpn.div); break
                    default: handled = false; break
                }

                if (!handled) {
                    handled = true
                    switch (e.text) {
                        case "+": op(rpn.add); break
                        case "-": op(rpn.sub); break
                        case "*": op(rpn.mul); break
                        case "/": op(rpn.div); break
                        case "^": op(rpn.pow); break
                        default: handled = false; break
                    }
                }

                if (handled) e.accepted = true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button { text: "π"; onClicked: rpn.pushPi() }
            Button { text: "e"; onClicked: rpn.pushE() }

            Button { text: "↶"; enabled: rpn.canUndo; onClicked: win.keepFocus(() => rpn.undo()) }
            Button { text: "↷"; enabled: rpn.canRedo; onClicked: win.keepFocus(() => rpn.redo()) }

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
            id: panes
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical
            clip: true

            handle: Rectangle {
                implicitHeight: win.splitHandleH
                color: panes.palette.mid
                opacity: 0.6
                radius: 4
            }

            // keep default ratio, but track user adjustments
            property real stackRatio: 0.70
            property bool applying: false

            function applyRatio() {
                applying = true

                const available = Math.max(0, panes.height - win.splitHandleH)
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

            Timer {
                id: sampleRatio
                interval: 0
                repeat: false
                onTriggered: {
                    if (panes.applying) return
                    const available = Math.max(1, panes.height - win.splitHandleH)
                    panes.stackRatio = Math.max(0.05, Math.min(0.95, stackFrame.height / available))
                }
            }

            Connections { target: stackFrame;   function onHeightChanged() { sampleRatio.restart() } }
            Connections { target: historyFrame; function onHeightChanged() { sampleRatio.restart() } }

            // ---- STACK ----
            Frame {
                id: stackFrame
                padding: 0
                SplitView.minimumHeight: win.stackMinH

                background: Rectangle {
                    id: stackBg
                    radius: win.cornerRadius
                    color: stackFrame.palette.window
                    border.color: stackFrame.palette.mid
                    border.width: 1
                }

                // true rounded clipping for the whole content
                Item {
                    id: stackClip
                    anchors.fill: parent
                    anchors.margins: stackBg.border.width

                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: stackClip.width
                            height: stackClip.height
                            radius: Math.max(0, win.cornerRadius - stackBg.border.width)
                            color: "white"
                        }
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
                            property bool showStackBar: false

                            Timer { id: stackBarTimer; interval: 700; repeat: false; onTriggered: stackList.showStackBar = false }

                            onContentYChanged: { stackList.showStackBar = true; stackBarTimer.restart() }
                            onMovementStarted: { stackList.showStackBar = true; stackBarTimer.restart() }
                            onMovementEnded: stackBarTimer.restart()

                            ScrollBar.vertical: ScrollBar {
                                id: stackVBar
                                policy: ScrollBar.AsNeeded
                                hoverEnabled: true
                                z: 100
                                width: 12
                                padding: 2

                                readonly property bool needed: stackList.contentHeight > stackList.height + 1
                                visible: needed
                                opacity: needed ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            delegate: Item {
                                id: rowItem
                                width: stackList.width
                                height: stackList.rowHeight

                                property bool editing: false
                                readonly property bool isSelected: ListView.isCurrentItem

                                HoverHandler { id: hoverH }

                                Rectangle {
                                    anchors.fill: parent
                                    color: rowItem.isSelected
                                        ? stackFrame.palette.highlight
                                        : (hoverH.hovered ? Qt.lighter(win.palette.highlight, 1.6) : stackFrame.palette.base)
                                    opacity: rowItem.isSelected ? 1.0 : (hoverH.hovered ? 0.22 : 1.0)
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    Behavior on opacity { NumberAnimation { duration: 80 } }
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
                                    onClicked: { stackList.currentIndex = index; input.forceActiveFocus() }
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

                                    Keys.onReturnPressed: function(e) { commit(); e.accepted = true }
                                    Keys.onEnterPressed:  function(e) { commit(); e.accepted = true }
                                    Keys.onEscapePressed: function(e) { rowItem.editing = false; input.forceActiveFocus(); e.accepted = true }
                                    onEditingFinished: { if (rowItem.editing) commit() }
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
                                    anchors.rightMargin: 6 + (stackVBar.visible ? stackVBar.width : 0)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 34
                                    height: 34
                                    text: "✕"
                                    onClicked: win.removeStackAt(index)
                                }
                            }
                        }

                        // arrows panel INSIDE the same rounded border
                        Rectangle {
                            id: arrowsPanel
                            Layout.preferredWidth: 48
                            Layout.fillHeight: true
                            color: stackFrame.palette.window

                            Rectangle {
                                width: 1
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                color: stackFrame.palette.mid
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                ToolButton {
                                    text: "▲"
                                    Layout.fillWidth: true
                                    enabled: stackList.currentIndex > 0
                                    onClicked: win.moveSelectedStack(-1)
                                }

                                ToolButton {
                                    text: "▼"
                                    Layout.fillWidth: true
                                    enabled: stackList.currentIndex >= 0 && stackList.currentIndex < stackList.count - 1
                                    onClicked: win.moveSelectedStack(+1)
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }
            }

            // ---- HISTORY ----
            Frame {
                id: historyFrame
                padding: 6
                SplitView.minimumHeight: win.historyMinH

                background: Rectangle {
                    radius: win.cornerRadius
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

                    Flickable {
                        id: historyFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.AutoFlickDirection

                        contentWidth: historyText.implicitWidth
                        contentHeight: historyText.implicitHeight

                        property bool showHistBars: false
                        Timer { id: histBarTimer; interval: 700; repeat: false; onTriggered: historyFlick.showHistBars = false }

                        onContentYChanged: { historyFlick.showHistBars = true; histBarTimer.restart() }
                        onContentXChanged: { historyFlick.showHistBars = true; histBarTimer.restart() }
                        onMovementStarted: { historyFlick.showHistBars = true; histBarTimer.restart() }
                        onMovementEnded: histBarTimer.restart()

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
                        }

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
                        }

                        TextEdit {
                            id: historyText
                            x: 0
                            y: 0
                            text: rpn.historyText
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.NoWrap
                            font.family: "Monospace"
                            color: historyFrame.palette.text
                            width: Math.max(historyFlick.width, implicitWidth)
                        }
                    }
                }
            }
        }

        // ===== keypad =====
        GridLayout {
            id: keypad
            Layout.fillWidth: true
            Layout.margins: 6
            columns: 5
            rowSpacing: 6
            columnSpacing: 8

            readonly property var keys: [
                { label:"7",    type:"char",  value:"7" },
                { label:"8",    type:"char",  value:"8" },
                { label:"9",    type:"char",  value:"9" },
                { label:"+",    type:"op",    value:"add" },
                { label:"-",    type:"op",    value:"sub" },

                { label:"4",    type:"char",  value:"4" },
                { label:"5",    type:"char",  value:"5" },
                { label:"6",    type:"char",  value:"6" },
                { label:"×",    type:"op",    value:"mul" },
                { label:"/",    type:"op",    value:"div" },

                { label:"1",    type:"char",  value:"1" },
                { label:"2",    type:"char",  value:"2" },
                { label:"3",    type:"char",  value:"3" },
                { label:"sqrt", type:"fn",    value:"sqrt" },
                { label:"xʸ",   type:"op",    value:"pow" },

                { label:"0",    type:"char",  value:"0" },
                { label:".",    type:"char",  value:"." },
                { label:"⌫",    type:"back",  value:"" },
                { label:"±",    type:"fn",    value:"neg" },
                { label:"dup",  type:"fn",    value:"dup" },

                { label:"sin",  type:"fn",    value:"sin" },
                { label:"cos",  type:"fn",    value:"cos" },
                { label:"swap", type:"fn",    value:"swap" },
                { label:"drop", type:"fn",    value:"drop" },
                { label:"ENTER",type:"enter", value:"" }
            ]

            function trigger(k) {
                switch (k.type) {
                    case "char":  win.appendChar(k.value); break
                    case "back":  win.backspace(); break
                    case "enter": win.doEnter(); break
                    case "op":
                        if      (k.value === "add") win.op(rpn.add)
                        else if (k.value === "sub") win.op(rpn.sub)
                        else if (k.value === "mul") win.op(rpn.mul)
                        else if (k.value === "div") win.op(rpn.div)
                        else if (k.value === "pow") win.op(rpn.pow)
                        break
                    case "fn":
                        if      (k.value === "sqrt") win.op(rpn.sqrt)
                        else if (k.value === "neg")  win.op(rpn.neg)
                        else if (k.value === "dup")  win.op(rpn.dup)
                        else if (k.value === "drop") win.op(rpn.drop)
                        else if (k.value === "swap") win.op(rpn.swap)
                        else if (k.value === "sin")  win.op(rpn.sin)
                        else if (k.value === "cos")  win.op(rpn.cos)
                        break
                }
            }

            function focusFirst() {
                const b = keypadRep.itemAt(0)
                if (b) b.forceActiveFocus()
            }

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

                    if (i < cols) b.KeyNavigation.up = input
                    else          b.KeyNavigation.up = keypadRep.itemAt(upIndex)
                }
            }

            Repeater {
                id: keypadRep
                model: keypad.keys
                delegate: KeyButton { key: modelData }
                onItemAdded: Qt.callLater(keypad.relinkNav)
                onItemRemoved: Qt.callLater(keypad.relinkNav)
            }

            Component.onCompleted: Qt.callLater(relinkNav)
        }
    }
}
