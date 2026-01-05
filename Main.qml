import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform as Native
import RpnCalc.Backend
import QtQml

ApplicationWindow {
    id: win
    width: 500; height: 720
    visible: true
    title: "RPN Calculator"
    minimumWidth: 500; minimumHeight: 640
    maximumWidth: 800; maximumHeight: 1200

    RpnEngine {
        id: rpn
        onErrorOccurred: (msg) => ui.showToast(msg)
    }

    Component.onCompleted: rpn.loadSessionState()
    onClosing: rpn.saveSessionState()

    MainForm {
        id: ui
        anchors.fill: parent
        focus: true // Ważne

        stackModel: rpn.stackModel
        historyText: rpn.historyText
        decimalSeparator: rpn.decimalSeparator
        canUndo: rpn.canUndo
        canRedo: rpn.canRedo

        onInputEnter: win.doEnter()
        onKeypadAction: (key) => win.handleKeypadTrigger(key)
        onStackRemoveRequest: (idx) => win.removeStackAt(idx)
        onStackMoveRequest: (delta) => win.moveSelectedStack(delta)
        onStackValueSet: (row, text) => rpn.stackModel.setValueAt(row, text)

        onPushPi: rpn.pushPi()
        onPushE: rpn.pushE()
        onUndoRequest: rpn.undo()
        onRedoRequest: rpn.redo()
        onClearAllRequest: {
            ui.inputText = ""
            rpn.clearAll()
            ui.forceInputFocus()
        }
        onClearHistoryRequest: rpn.clearHistory()
    }

    // --- LOGIC ---
    function doEnter() {
        if (ui.inputText.trim().length > 0) {
            if (rpn.enter(ui.inputText)) ui.inputText = ""
        } else {
            rpn.dup()
        }
    }

    function appendChar(s) { ui.inputText += s }

    function backspace() {
        if (ui.inputText.length > 0)
            ui.inputText = ui.inputText.slice(0, -1)
    }

    function op(fn) {
        if (ui.inputText.trim().length > 0) {
            if (!rpn.enter(ui.inputText)) return
            ui.inputText = ""
        }
        fn()
    }

    function handleKeypadTrigger(k) {
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
                else if (k.value === "root") win.op(rpn.root)
                break

            case "fn":
                if      (k.value === "neg")  win.op(rpn.neg)
                else if (k.value === "dup")  win.op(rpn.dup)
                else if (k.value === "drop") win.op(rpn.drop)
                else if (k.value === "inv")  win.op(rpn.reciprocal)
                else if (k.value === "sin")  win.op(rpn.sin)
                else if (k.value === "cos")  win.op(rpn.cos)
                break
        }
    }

    function removeStackAt(row) {
        if (row < 0 || row >= ui.stackCount) return
        const cur = ui.stackCurrentIndex
        rpn.stackModel.removeAt(row)
        if (ui.stackCount === 0) ui.stackCurrentIndex = -1
        else if (cur >= row) ui.stackCurrentIndex = Math.max(0, cur - 1)
        ui.ensureStackVisible(ui.stackCurrentIndex)
    }

    function moveSelectedStack(delta) {
        const i = ui.stackCurrentIndex
        if (i < 0) return
        if (delta < 0) {
            if (rpn.stackModel.moveUp(i)) ui.stackCurrentIndex = i - 1
        } else {
            if (rpn.stackModel.moveDown(i)) ui.stackCurrentIndex = i + 1
        }
        ui.ensureStackVisible(ui.stackCurrentIndex)
    }

    // --- MENU ---
    Native.MenuBar {
        Native.Menu {
            title: "Notation"
            Native.MenuItemGroup { id: fmtGroup; exclusive: true }
            Native.MenuItem { text: "Scientific";  checkable: true; checked: rpn.formatMode === 0; group: fmtGroup; onTriggered: rpn.formatMode = 0 }
            Native.MenuItem { text: "Engineering"; checkable: true; checked: rpn.formatMode === 1; group: fmtGroup; onTriggered: rpn.formatMode = 1 }
            Native.MenuItem { text: "Simple";      checkable: true; checked: rpn.formatMode === 2; group: fmtGroup; onTriggered: rpn.formatMode = 2 }
        }
        Native.Menu {
            title: "History"
            Native.MenuItem { text: "Clear history"; onTriggered: rpn.clearHistory() }
        }
        Native.Menu {
            title: "Edit"
            Native.MenuItem { text: "Undo"; shortcut: "Ctrl+Z"; enabled: rpn.canUndo; onTriggered: rpn.undo() }
            Native.MenuItem { text: "Redo"; shortcut: "Ctrl+Shift+Z"; enabled: rpn.canRedo; onTriggered: rpn.redo() }
        }
        Native.Menu {
            title: "Help"
            Native.MenuItem { text: "Open GitHub Repository"; onTriggered: Qt.openUrlExternally("https://github.com/marek2001/RpnCalcQuick/") }
            Native.MenuItem { text: "Instructions"; onTriggered: Qt.openUrlExternally("https://github.com/marek2001/RpnCalcQuick/#readme") }
            Native.MenuSeparator { }
            Native.MenuItem { text: "About"; onTriggered: aboutDialog.open() }
        }
    }

    Native.MessageDialog {
        id: aboutDialog
        title: "About RPN Calculator"
        text: "RPN Calculator (Qt Quick)\nBuilt with Qt Quick Controls."
        buttons: Native.MessageDialog.Ok
    }

    // --- ZOSTAWIAMY TYLKO TE SKRÓTY (Resztę łapie MainForm) ---
    Shortcut { sequence: "Shift+Up";   context: Qt.ApplicationShortcut;
        enabled: !ui.isStackEditing && ui.stackCurrentIndex > 0; onActivated: win.moveSelectedStack(-1) }
    Shortcut { sequence: "Shift+Down"; context: Qt.ApplicationShortcut;
        enabled: !ui.isStackEditing && ui.stackCurrentIndex >= 0 && ui.stackCurrentIndex < ui.stackCount - 1;
        onActivated: win.moveSelectedStack(+1) }
}