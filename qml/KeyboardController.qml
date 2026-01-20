import QtQuick 2.15

// Maps keyboard events to calculator actions
QtObject {
    id: controller
    
    signal keyPressed(string key)
    signal navigationRequested(int delta)
    signal focusRequested()
    signal keypadFocusRequested()
    signal stackEditRequested()
    
    readonly property var keyMap: ({
        "BACK": "⌫",
        "ENTER": "ENTER",
        "CLEAR": "CLEAR",
        ".": "DECIMAL",
        ",": "DECIMAL",
        "+": "+",
        "-": "-",
        "*": "×",
        "×": "×",
        "/": "/",
        "^": "xʸ",
        "n": "±",
        "r": "ˣ√ᵧ",
        "s": "sin",
        "c": "cos",
        "d": "dup",
        "x": "drop",
        "i": "1/x"
    })
    
    function handleKeyEvent(event, isEditing) {
        if (isEditing) return false;
        
        // F2 - stack editing
        if (event.key === Qt.Key_F2) {
            stackEditRequested();
            return true;
        }
        
        // Shift + Up/Down - move stack
        if (event.modifiers & Qt.ShiftModifier) {
            if (event.key === Qt.Key_Up) {
                navigationRequested(-1);
                return true;
            }
            if (event.key === Qt.Key_Down) {
                navigationRequested(1);
                return true;
            }
        }
        
        // Down - focus on keypad
        if (event.key === Qt.Key_Down) {
            keypadFocusRequested();
            return true;
        }
        
        // Map keys
        let raw = event.text;
        if (event.key === Qt.Key_Backspace) raw = "BACK";
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) raw = "ENTER";
        else if (event.key === Qt.Key_Escape) raw = "CLEAR";
        
        const mapped = mapKey(raw);
        if (mapped) {
            keyPressed(mapped);
            return true;
        }
        
        return false;
    }
    
    function mapKey(raw) {
        if (!raw) return null;
        const lower = raw.toLowerCase ? raw.toLowerCase() : raw;
        
        // Check if it's a digit
        if (/[0-9]/.test(raw)) return raw;
        
        // Check mapping
        return keyMap[lower] || null;
    }
}
