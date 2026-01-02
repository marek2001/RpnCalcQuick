import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform as Native
import RpnCalc.Backend 0.6

ApplicationWindow {
    id: win
    width: 500
    height: 720
    visible: true
    title: "RPN Calculator (Qt Quick)"
    minimumWidth: 500
    minimumHeight: 640
    maximumWidth: 800
    maximumHeight: 1200

    // ===== 1. BACKEND (C++) =====
    RpnEngine {
        id: rpn
        // Przekazujemy błędy do toasta w formularzu
        onErrorOccurred: (msg) => ui.showToast(msg)
    }

    Component.onCompleted: rpn.loadSessionState()
    onClosing: rpn.saveSessionState()

    // ===== 2. VIEW (Formularz) =====
    MainForm {
        id: ui
        anchors.fill: parent

        // Wstrzykiwanie danych do widoku
        stackModel: rpn.stackModel
        historyText: rpn.historyText
        decimalSeparator: rpn.decimalSeparator
        canUndo: rpn.canUndo
        canRedo: rpn.canRedo

        // Obsługa sygnałów z widoku (akcje użytkownika)
        onInputEnter: win.doEnter()
        onKeypadAction: (key) => win.handleKeypadTrigger(key)
        onStackRemoveRequest: (idx) => win.removeStackAt(idx)
        onStackMoveRequest: (delta) => win.moveSelectedStack(delta)
        onStackValueSet: (row, text) => rpn.stackModel.setValueAt(row, text)

        onPushPi: rpn.pushPi()
        onPushE: rpn.pushE()
        onUndoRequest: win.keepFocus(() => rpn.undo())
        onRedoRequest: win.keepFocus(() => rpn.redo())
        onClearAllRequest: {
            ui.inputText = ""
            rpn.clearAll()
            ui.forceInputFocus()
        }
    }

    // ===== 3. LOGIKA APLIKACJI =====

    // allow typing if we are not editing the stack inline within the UI
    readonly property bool allowGlobalTyping: !ui.isStackEditing

    function keepFocus(doWork) {
        const prev = win.activeFocusItem
        doWork()
        if (prev && prev !== ui.inputItem && win.activeFocusItem === ui.inputItem)
            prev.forceActiveFocus()
    }

    function autoEnterIfNeeded() {
        const t = ui.inputText.trim()
        if (t.length > 0 && rpn.enter(t))
            ui.inputText = ""
    }

    function doEnter() {
        keepFocus(() => {
            if (rpn.enter(ui.inputText))
                ui.inputText = ""
        })
    }

    function op(fn) {
        keepFocus(() => {
            autoEnterIfNeeded()
            fn()
        })
    }

    function appendChar(s) {
        keepFocus(() => { ui.inputText = ui.inputText + s })
    }

    function backspace() {
        keepFocus(() => {
            if (ui.inputText.length > 0)
                ui.inputText = ui.inputText.slice(0, ui.inputText.length - 1)
        })
    }

    function removeStackAt(row) {
        if (row < 0 || row >= ui.stackCount) return
        const cur = ui.stackCurrentIndex
        rpn.stackModel.removeAt(row)

        // Logika selekcji po usunięciu (UI logic helper)
        if (ui.stackCount === 0) {
            ui.stackCurrentIndex = -1
            return
        }
        if (cur === -1) ui.stackCurrentIndex = 0
        else if (cur > row) ui.stackCurrentIndex = cur - 1
        else if (cur === row) ui.stackCurrentIndex = Math.min(row, ui.stackCount - 1)

        ui.ensureStackVisible(ui.stackCurrentIndex)
        ui.forceInputFocus()
    }

    function moveSelectedStack(delta) {
        const i = ui.stackCurrentIndex
        if (i < 0) return
        if (delta < 0 && i > 0) {
            if (rpn.stackModel.moveUp(i)) {
                ui.stackCurrentIndex = i - 1
                ui.ensureStackVisible(ui.stackCurrentIndex)
            }
        } else if (delta > 0 && i < ui.stackCount - 1) {
            if (rpn.stackModel.moveDown(i)) {
                ui.stackCurrentIndex = i + 1
                ui.ensureStackVisible(ui.stackCurrentIndex)
            }
        }
    }

    // Obsługa kliknięcia w klawiaturę ekranową
    function handleKeypadTrigger(k) {
        switch (k.type) {
            case "char":  win.appendChar(k.value); break
            case "back":  win.backspace(); break
            case "enter": win.doEnter(); break
            case "op":
                if      (k.value === "root") win.op(rpn.root)
                else if (k.value === "add") win.op(rpn.add)
                else if (k.value === "sub") win.op(rpn.sub)
                else if (k.value === "mul") win.op(rpn.mul)
                else if (k.value === "div") win.op(rpn.div)
                else if (k.value === "pow") win.op(rpn.pow)
                break
            case "fn":
                if      (k.value === "root") win.op(rpn.root)
                // if      (k.value === "sqrt") win.op(rpn.sqrt)
                else if (k.value === "neg")  win.op(rpn.neg)
                else if (k.value === "dup")  win.op(rpn.dup)
                else if (k.value === "drop") win.op(rpn.drop)
                else if (k.value === "inv")  win.op(rpn.reciprocal)
                else if (k.value === "sin")  win.op(rpn.sin)
                else if (k.value === "cos")  win.op(rpn.cos)
                break
        }
    }

    // ===== 4. GLOBALNE MENU =====
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
            Instantiator {
                model: 13
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

    // ===== 5. SKRÓTY KLAWISZOWE =====
    // Wywołują ui.simulatePress, aby przyciski w widoku "mignęły"

    Shortcut {
        sequences: [ "Return", "Enter", StandardKey.InsertParagraphSeparator]
        enabled: !ui.isStackEditing && !ui.inputItem.activeFocus
        onActivated: ui.simulatePress("ENTER")
    }
    Shortcut {
        sequence: "Backspace"
        enabled: win.allowGlobalTyping && !ui.inputItem.activeFocus
        onActivated: ui.simulatePress("BACK")
    }
    Shortcut { sequence: "Shift+Up";   context: Qt.ApplicationShortcut; enabled: !ui.isStackEditing && ui.stackCurrentIndex > 0; onActivated: win.moveSelectedStack(-1) }
    Shortcut { sequence: "Shift+Down"; context: Qt.ApplicationShortcut; enabled: !ui.isStackEditing && ui.stackCurrentIndex >= 0 && ui.stackCurrentIndex < ui.stackCount - 1; onActivated: win.moveSelectedStack(+1) }

    Repeater {
        model: 10
        delegate: Item {
            visible: false
            Shortcut {
                sequence: modelData.toString()
                context: Qt.ApplicationShortcut
                enabled: win.allowGlobalTyping && !ui.inputItem.activeFocus
                onActivated: ui.simulatePress(modelData.toString())
            }
        }
    }
    // Separators
    Item { visible: false; Shortcut { sequence: "."; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping && !ui.inputItem.activeFocus; onActivated: ui.simulatePress(".") } }
    Item { visible: false; Shortcut { sequence: ","; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping && !ui.inputItem.activeFocus; onActivated: ui.simulatePress(",") } }

    Shortcut { sequence: StandardKey.Undo; onActivated: rpn.undo() }
    Shortcut { sequence: StandardKey.Redo; onActivated: rpn.redo() }

    Shortcut { sequence: "+"; onActivated: ui.simulatePress("+") }
    Shortcut { sequence: "-"; onActivated: ui.simulatePress("-") }
    Shortcut { sequence: "*"; onActivated: ui.simulatePress("*") }
    Shortcut { sequence: "/"; onActivated: ui.simulatePress("/") }
    Shortcut { sequence: "^"; onActivated: ui.simulatePress("^") }

    Shortcut { sequence: "Multiply"; onActivated: ui.simulatePress("*") }
    Shortcut { sequence: "Divide";   onActivated: ui.simulatePress("/") }
    Shortcut { sequence: "Add";      onActivated: ui.simulatePress("+") }
    Shortcut { sequence: "Subtract"; onActivated: ui.simulatePress("-") }

    Shortcut { sequence: "S"; onActivated: ui.simulatePress("sin") }
    Shortcut { sequence: "C"; onActivated: ui.simulatePress("cos") }
    Shortcut { sequence: "N"; onActivated: ui.simulatePress("neg") }
    Shortcut { sequence: "D"; onActivated: ui.simulatePress("dup") }
    Shortcut { sequence: "X"; onActivated: ui.simulatePress("drop") }
    // Shortcut { sequence: "R"; onActivated: ui.simulatePress("sqrt") }
    Shortcut { sequence: "R"; onActivated: ui.simulatePress("root") }
    Shortcut { sequence: "I"; onActivated: ui.simulatePress("inv") }
    
}
