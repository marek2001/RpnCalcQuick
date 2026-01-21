import QtQuick 2.15

// Manages input text state and validation
QtObject {
    id: handler
    
    property string text: ""
    property string decimalSeparator: "."
    property int maxDigits: 15
    
    signal validationFailed(string message)
    
    function appendChar(character) {
        const isDigit = /[0-9]/.test(character);
        if (isDigit) {
            const currentDigits = text.replace(/[^0-9]/g, "").length;
            if (currentDigits >= maxDigits) {
                validationFailed("Maximum precision (15 digits)");
                return false;
            }
        }
        text += character;
        return true;
    }
    
    function backspace() {
        if (text.length > 0) {
            text = text.slice(0, -1);
        }
    }
    
    function clear() {
        text = "";
    }
    
    function setText(newText) {
        text = newText;
    }
}
