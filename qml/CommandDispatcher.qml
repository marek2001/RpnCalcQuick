import QtQuick 2.15

// Dispatches commands to RPN engine
QtObject {
    id: dispatcher
    
    property var rpnEngine: null
    property var inputHandler: null
    
    function execute(keyLabel, keepFocusFn) {
        if (!rpnEngine || !inputHandler) return;
        
        // Map keys to actions
        switch (keyLabel) {
            case "0": case "1": case "2": case "3": case "4":
            case "5": case "6": case "7": case "8": case "9":
                keepFocusFn(function() { inputHandler.appendChar(keyLabel); });
                break;
                
            case "DECIMAL":
                keepFocusFn(function() { inputHandler.appendChar(rpnEngine.decimalSeparator); });
                break;
                
            case "⌫":
                keepFocusFn(function() { inputHandler.backspace(); });
                break;
                
            case "ENTER":
                doEnter(keepFocusFn);
                break;
                
            case "+":
                doOp(keepFocusFn, rpnEngine.add);
                break;
            case "-":
                doOp(keepFocusFn, rpnEngine.sub);
                break;
            case "×":
                doOp(keepFocusFn, rpnEngine.mul);
                break;
            case "/":
                doOp(keepFocusFn, rpnEngine.div);
                break;
            case "xʸ":
                doOp(keepFocusFn, rpnEngine.pow);
                break;
            case "ˣ√ᵧ":
                doOp(keepFocusFn, rpnEngine.root);
                break;
                
            case "±":
                doOp(keepFocusFn, rpnEngine.neg);
                break;
            case "dup":
                doOp(keepFocusFn, rpnEngine.dup);
                break;
            case "drop":
                doOp(keepFocusFn, rpnEngine.drop);
                break;
            case "1/x":
                doOp(keepFocusFn, rpnEngine.reciprocal);
                break;
            case "sin":
                doOp(keepFocusFn, rpnEngine.sin);
                break;
            case "cos":
                doOp(keepFocusFn, rpnEngine.cos);
                break;
        }
    }
    
    function doEnter(keepFocusFn) {
        keepFocusFn(function() {
            if (inputHandler.text.trim().length > 0) {
                if (rpnEngine.enter(inputHandler.text)) {
                    inputHandler.clear();
                }
            } else {
                rpnEngine.dup();
            }
        });
    }
    
    function doOp(keepFocusFn, opFn) {
        keepFocusFn(function() {
            if (inputHandler.text.trim().length > 0) {
                if (!rpnEngine.enter(inputHandler.text)) return;
                inputHandler.clear();
            }
            opFn();
        });
    }
}
