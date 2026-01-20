import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt.labs.platform as Native
import RpnCalc.Backend
import QtQml

ApplicationWindow {
    id: win
    width: 360;
    height: 620
    visible: true
    title: "RPN Calculator"
    minimumWidth: 320
    minimumHeight: 540
    maximumWidth: 800
    maximumHeight: 1200

    RpnEngine {
        id: rpn
        onErrorOccurred: (msg) => ui.showToast(msg)
    }

    Component.onCompleted: rpn.loadSessionState()
    onClosing: rpn.saveSessionState()
    // =========================================================
    // MENU LOGIC: KDE vs OTHERS
    // =========================================================

    // 1. Jeśli NIE jesteśmy na KDE, przypisujemy pasek wbudowany do okna.
    // Jeśli to nie KDE i nie Windows -> użyj paska wbudowanego (QQC2)
    // W przeciwnym razie (KDE lub Windows) -> null (bo użyjemy Native)
    menuBar: (!rpn.isKde && Qt.platform.os !== "windows") ? inWindowMenuBar : null

    // Definicja paska wbudowanego (QQC2 - dla Cinnamon, GNOME etc.)
    MenuBar {
        id: inWindowMenuBar
        Menu {
            title: "Notation"
            ActionGroup { id: fmtGroupQQC }
            Action { text: "Scientific";  checkable: true; checked: rpn.formatMode === 0;
                ActionGroup.group: fmtGroupQQC; onTriggered: rpn.formatMode = 0 }
            Action { text: "Engineering"; checkable: true; checked: rpn.formatMode === 1;
                ActionGroup.group: fmtGroupQQC; onTriggered: rpn.formatMode = 1 }
            Action { text: "Simple";      checkable: true; checked: rpn.formatMode === 2;
                ActionGroup.group: fmtGroupQQC; onTriggered: rpn.formatMode = 2 }
        }
        Menu {
            title: "History"
            Action { text: "Clear history"; onTriggered: rpn.clearHistory() }
        }
        Menu {
            title: "Edit"
            Action { text: "Undo"; shortcut: "Ctrl+Z"; enabled: rpn.canUndo; onTriggered: rpn.undo() }
            Action { text: "Redo"; shortcut: "Ctrl+Shift+Z"; enabled: rpn.canRedo; onTriggered: rpn.redo() }
        }
        Menu {
            title: "Help"
            Action { text: "Open GitHub Repository";
                onTriggered: Qt.openUrlExternally("https://github.com/marek2001/RpnCalcQuick/") }
            Action { text: "Instructions";
                onTriggered: Qt.openUrlExternally("https://github.com/marek2001/RpnCalcQuick/#readme") }
            MenuSeparator { }
            Action { text: "About"; onTriggered: aboutDialog.open() }
        }
    }

    // 2. Jeśli JESTEŚMY na KDE, ładujemy natywny pasek (Global Menu).
    Loader {
        active: rpn.isKde || Qt.platform.os === "windows"
        sourceComponent: Native.MenuBar {
            Native.Menu {
                title: "Notation"
                Native.MenuItemGroup { id: fmtGroupNative; exclusive: true }
                Native.MenuItem { text: "Scientific";  checkable: true; checked: rpn.formatMode === 0;
                    group: fmtGroupNative; onTriggered: rpn.formatMode = 0 }
                Native.MenuItem { text: "Engineering"; checkable: true; checked: rpn.formatMode === 1;
                    group: fmtGroupNative; onTriggered: rpn.formatMode = 1 }
                Native.MenuItem { text: "Simple";      checkable: true; checked: rpn.formatMode === 2;
                    group: fmtGroupNative; onTriggered: rpn.formatMode = 2 }
            }
            Native.Menu {
                title: "History"
                Native.MenuItem { text: "Clear history"; onTriggered: rpn.clearHistory() }
            }
            Native.Menu {
                title: "Edit"
                Native.MenuItem { text: "Undo"; shortcut: "Ctrl+Z"; enabled: rpn.canUndo; onTriggered: rpn.undo() }
                Native.MenuItem { text: "Redo"; shortcut: "Ctrl+Shift+Z"; enabled: rpn.canRedo;
                    onTriggered: rpn.redo() }
            }
            Native.Menu {
                title: "Help"
                Native.MenuItem { text: "Open GitHub Repository";
                    onTriggered: Qt.openUrlExternally("https://github.com/marek2001/RpnCalcQuick/") }
                Native.MenuItem { text: "Instructions";
                    onTriggered: Qt.openUrlExternally("https://github.com/marek2001/RpnCalcQuick/#readme") }
                Native.MenuSeparator { }
                Native.MenuItem { text: "About"; onTriggered: aboutDialog.open() }
            }
        }
    }

    Native.MessageDialog {
        id: aboutDialog
        title: "About RPN Calculator"
        text: "RPN Calculator (Qt Quick)\nBuilt with Qt Quick Controls."
        buttons: Native.MessageDialog.Ok
    }

    // =========================================================
    MainForm {
        id: ui
        anchors.fill: parent
        focus: true

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
        }
        onClearHistoryRequest: rpn.clearHistory()
        stackChangeCallback: (row, text) => rpn.modifyStackValue(row, text)
    }

    // --- LOGIC ---
    function keepFocus(doWork) {
        const prev = win.activeFocusItem;
        doWork();
        if (prev && prev !== ui.inputItem && win.activeFocusItem === ui.inputItem) {
            prev.forceActiveFocus();
        }
    }

    function doEnter() {
        keepFocus(() => {
            if (ui.inputText.trim().length > 0) {
                if (rpn.enter(ui.inputText)) ui.inputText = ""
            } else {
                rpn.dup()
            }
        })
    }

    function appendChar(s) {
        keepFocus(() => {
            const isDigit = (s >= '0' && s <= '9');
            if (isDigit) {
                const currentDigits = ui.inputText.replace(/[^0-9]/g, "").length;
                if (currentDigits >= 15) {
                    ui.showToast("Maksymalna precyzja (15 cyfr)");
                    return;
                }
            }
            ui.inputText += s
        })
    }

    function backspace() {
        keepFocus(() => {
            if (ui.inputText.length > 0)
                ui.inputText = ui.inputText.slice(0, -1)
        })
    }

    function op(fn) {
        keepFocus(() => {
            if (ui.inputText.trim().length > 0) {
                if (!rpn.enter(ui.inputText)) return
                ui.inputText = ""
            }
            fn()
        })
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
    
    readonly property bool allowGlobalTyping: !ui.isStackEditing

    // --- GLOBALNE SKRÓTY KLAWISZOWE ---

    // 1. Nawigacja stosem
    Shortcut { sequence: "Shift+Up";   context: Qt.ApplicationShortcut;
        enabled: !ui.isStackEditing && ui.stackCurrentIndex > 0; onActivated: win.moveSelectedStack(-1) }
    Shortcut { sequence: "Shift+Down"; context: Qt.ApplicationShortcut;
        enabled: !ui.isStackEditing && ui.stackCurrentIndex >= 0 && ui.stackCurrentIndex < ui.stackCount - 1;
        onActivated: win.moveSelectedStack(+1) }

    // 2. ENTER
    Shortcut {
        sequence: StandardKey.Return // Enter na głównej klawiaturze
        context: Qt.ApplicationShortcut
        enabled: !ui.isStackEditing
        onActivated: ui.simulatePress("ENTER")
    }
    Shortcut {
        sequence: StandardKey.Enter // Enter na klawiaturze numerycznej
        context: Qt.ApplicationShortcut
        enabled: !ui.isStackEditing
        onActivated: ui.simulatePress("ENTER")
    }

    // 3. Backspace
    Shortcut {
        sequence: "Backspace"
        context: Qt.ApplicationShortcut
        enabled: win.allowGlobalTyping
        onActivated: ui.simulatePress("BACK")
    }

    // 4. Cyfry 0-9
    Repeater {
        model: 10
        delegate: Item {
            visible: false
            Shortcut {
                sequence: modelData.toString()
                context: Qt.ApplicationShortcut
                enabled: win.allowGlobalTyping
                onActivated: ui.simulatePress(modelData.toString())
            }
        }
    }

    // 5. Separatory dziesiętne
    Shortcut { sequence: "."; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress(".") }
    Shortcut { sequence: ","; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress(",") }

    // 6. Undo / Redo
    Shortcut { sequences: [StandardKey.Undo]; context: Qt.ApplicationShortcut; onActivated: rpn.undo() }
    Shortcut { sequences: [StandardKey.Redo]; context: Qt.ApplicationShortcut; onActivated: rpn.redo() }

    // 7. Operatory (+, -, *, /)
    // UWAGA: "=" działa jako plus (dla wygody na klawiaturze bez numpad)
    Shortcut { sequence: "="; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("+") }
    Shortcut { sequence: "+"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("+") }

    Shortcut { sequence: "-"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("-") }
    Shortcut { sequence: "*"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("*") }
    Shortcut { sequence: "/"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("/") }
    Shortcut { sequence: "^"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("^") }

    // Numpad words
    Shortcut { sequence: "Multiply"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("*") }
    Shortcut { sequence: "Divide";   context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("/") }
    Shortcut { sequence: "Add";      context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("+") }
    Shortcut { sequence: "Subtract"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("-") }

    // 8. Litery / Funkcje (Poprawione: Małe litery + wysyłanie znaku, nie nazwy funkcji)
    // Dzięki wysyłaniu "s" (a nie "sin"), MainForm poprawnie mapuje klawisz na przycisk.
    Shortcut { sequence: "s"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("s") }
    Shortcut { sequence: "c"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("c") }
    Shortcut { sequence: "n"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("n") }
    Shortcut { sequence: "d"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("d") }
    Shortcut { sequence: "x"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("x") }
    Shortcut { sequence: "r"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("r") }
    Shortcut { sequence: "i"; context: Qt.ApplicationShortcut; enabled: win.allowGlobalTyping;
        onActivated: ui.simulatePress("i") }
}