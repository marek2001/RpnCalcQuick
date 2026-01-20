import QtQuick 2.15

// Handles number display formatting with digit grouping
QtObject {
    id: formatter
    
    function formatNumber(raw) {
        if (!raw || raw.trim() === "") return "";
        
        const locale = Qt.locale();
        const sep = locale.groupSeparator;
        const dec = locale.decimalPoint;
        
        // Clean everything that's not a digit, separator, or minus
        let cleaned = raw.replace(/[^0-9.,\-]/g, '');
        let parts = cleaned.split(dec);
        
        // If more than one decimal separator, return original
        if (parts.length > 2) return raw;
        
        let intPart = parts[0];
        let decPart = parts.length > 1 ? dec + parts[1] : '';
        
        // Group integer part (from right side)
        let reversed = intPart.split('').reverse().join('');
        let grouped = reversed.replace(/(\d{3})(?=\d)/g, '$1' + sep);
        let finalInt = grouped.split('').reverse().join('');
        
        return finalInt + decPart;
    }
}
