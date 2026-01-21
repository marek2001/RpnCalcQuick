#include "rpnstackmodel.h"

#include <QLocale>
#include <QtGlobal>
#include <cmath>

RpnStackModel::RpnStackModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int RpnStackModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_stack.size();
}

QHash<int, QByteArray> RpnStackModel::roleNames() const
{
    return { { ValueRole, "value" } };
}

// --- PARSING ---
double RpnStackModel::parseInput(const QString &text, bool *ok)
{
    QString t = text.trimmed();
    if (t.isEmpty()) {
        if (ok) *ok = false;
        return 0.0;
    }

    // 1. CRITICAL CLEANUP:
    // QLocale::c() accepts ONLY dots. If commas remain, E-notation parsing will fail.
    t.replace(',', '.');
    
    // Remove ALL spaces (regular and non-breaking), 
    // because "1.23 E 5" is invalid for toDouble().
    t.remove(' ');
    t.remove(QChar(0xA0)); // U+00A0 (Non-breaking space)

    double v = 0.0;
    bool status = false;

    // 2. Handle scientific notation "a*10^b"
    if (const int splitIdx = t.indexOf("*10^"); splitIdx > 0) {
        const QString aStr = t.left(splitIdx);
        const QString bStr = t.mid(splitIdx + 4); // length of "*10^" is 4

        // Compose format "mantissaEb", e.g. "1.23E5"
        // Because t.replace() and t.remove() worked earlier, 
        // aStr already has dots and no spaces.
        QString scientificStr = aStr + "E" + bStr;
        
        v = QLocale::c().toDouble(scientificStr, &status);
        
        // FALLBACK:
        // If E-notation method fails (e.g. weird format), try old method,
        // so user doesn't get stuck.
        if (!status) {
            bool okA = false, okB = false;
            const double a = QLocale::c().toDouble(aStr, &okA);
            const int b = bStr.toInt(&okB);
            if (okA && okB) {
                v = a * std::pow(10.0, b);
                status = std::isfinite(v);
            }
        }
    } else {
        // 3. Standard parsing (e.g. 123.45)
        v = QLocale::c().toDouble(t, &status);
    }
    
    if (status) {
        status = std::isfinite(v);
    }

    if (ok) *ok = status;
    return status ? v : 0.0;
}

// --- FORMATTING ---
QString RpnStackModel::formatValue(double v) const
{
    if (!std::isfinite(v)) return QStringLiteral("NaN");
    if (v == 0.0) return QStringLiteral("0");

    const double absV = std::abs(v);
    const QLocale loc = QLocale::system();
    const QString decimalPoint = loc.decimalPoint();

    // Function to remove trailing zeros (e.g. "1.500" -> "1.5")
    auto cleanZerosLocale = [&](QString s) -> QString {
        if (s.contains(decimalPoint)) {
            while (s.endsWith('0')) s.chop(1);
            if (s.endsWith(decimalPoint)) s.chop(decimalPoint.length());
        }
        return s;
    };

    switch (m_mode) {
        case Scientific: {
            int exp = static_cast<int>(std::floor(std::log10(absV)));
            double mant = v / std::pow(10.0, exp);

            // [FIX] Scientific always has 1 digit before decimal point.
            // Safe max after decimal is 15 - 1 = 14.
            int safePrec = qBound(0, m_precision, 14);

            QString mantStr = cleanZerosLocale(loc.toString(mant, 'f', safePrec));
            return QString("%1 * 10^%2").arg(mantStr).arg(exp);
        }
        case Engineering: {
            int exp = static_cast<int>(std::floor(std::log10(absV)));
            exp = (exp / 3) * 3; // Round exponent to multiple of 3
            double mant = v / std::pow(10.0, exp);

            // [FIX] Calculate "budget" of digits for mantissa
            // Mantissa in engineering mode can be e.g. 1.2, 12.3 or 123.4
            double absMant = std::abs(mant);
            int intDigits = 1;
            if (absMant >= 100.0) intDigits = 3;
            else if (absMant >= 10.0) intDigits = 2;

            // How many decimal places can we show without exceeding 15 significant digits?
            // Max 15 - (integer digits). E.g. for "123.xxx" we have 12 places left.
            int maxDecimals = 15 - intDigits;
            int safePrec = qBound(0, m_precision, maxDecimals);

            QString mantStr = cleanZerosLocale(loc.toString(mant, 'f', safePrec));
            return QString("%1 * 10^%2").arg(mantStr).arg(exp);
        }
        case Simple:
        default: {
            // [FIX] If number is very large or very small, force scientific notation
            if (absV >= 1.0e15 || (absV > 0 && absV < 1.0e-15)) {
                // Call Scientific logic manually (to avoid code duplication, could extract to function,
                // but here for readability we paste Scientific logic)
                int exp = static_cast<int>(std::floor(std::log10(absV)));
                double mant = v / std::pow(10.0, exp);
                int safePrec = 14; 
                QString mantStr = cleanZerosLocale(loc.toString(mant, 'f', safePrec));
                return QString("%1 * 10^%2").arg(mantStr).arg(exp);
            }

            // Normal mode - max 15 digits
            int safePrec = qBound(0, m_precision, 15);
            QString s = loc.toString(v, 'f', safePrec);
            s = cleanZerosLocale(s);
            if (s == QStringLiteral("-0")) s = QStringLiteral("0");
            return s;
        }
    }
}


QVariant RpnStackModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) return {};
    const int row = index.row();
    if (row < 0 || row >= m_stack.size()) return {};

    if (role == ValueRole)
        return formatValue(m_stack[row]);

    return {};
}

void RpnStackModel::setNumberFormat(int mode, int precision)
{
    if (mode < 0 || mode > 2) mode = 0;
    if (precision < 0) precision = 0;
    if (precision > 17) precision = 17;

    const auto newMode = static_cast<NumberFormat>(mode);
    const bool changed = (newMode != m_mode) || (precision != m_precision);

    m_mode = newMode;
    m_precision = precision;

    if (changed && !m_stack.isEmpty())
        emit dataChanged(index(0), index(m_stack.size() - 1), { ValueRole });
}

// --- STACK OPS ---
bool RpnStackModel::has(int n) const { return m_stack.size() >= n; }

void RpnStackModel::push(double v)
{
    beginInsertRows(QModelIndex(), 0, 0);
    m_stack.prepend(v);
    endInsertRows();
}

bool RpnStackModel::pop(double &v)
{
    if (m_stack.isEmpty()) return false;
    beginRemoveRows(QModelIndex(), 0, 0);
    v = m_stack.takeFirst();
    endRemoveRows();
    return true;
}

bool RpnStackModel::dupTop()
{
    if (m_stack.isEmpty()) return false;
    beginInsertRows(QModelIndex(), 0, 0);
    m_stack.prepend(m_stack.first());
    endInsertRows();
    return true;
}

bool RpnStackModel::swapTop()
{
    if (m_stack.size() < 2) return false;
    beginResetModel();
    std::swap(m_stack[0], m_stack[1]);
    endResetModel();
    return true;
}

bool RpnStackModel::dropTop()
{
    if (m_stack.isEmpty()) return false;
    beginRemoveRows(QModelIndex(), 0, 0);
    m_stack.removeFirst();
    endRemoveRows();
    return true;
}

void RpnStackModel::clearAll()
{
    beginResetModel();
    m_stack.clear();
    endResetModel();
}

void RpnStackModel::restore(const QVector<double> &s)
{
    beginResetModel();
    m_stack = s;
    endResetModel();
}

// --- QML HELPER OPS ---
void RpnStackModel::removeAt(int row)
{
    if (row < 0 || row >= m_stack.size()) return;
    beginRemoveRows(QModelIndex(), row, row);
    m_stack.removeAt(row);
    endRemoveRows();
}

bool RpnStackModel::moveUp(int row)
{
    if (row <= 0 || row >= m_stack.size()) return false;
    beginResetModel();
    std::swap(m_stack[row], m_stack[row - 1]);
    endResetModel();
    return true;
}

bool RpnStackModel::moveDown(int row)
{
    if (row < 0 || row >= m_stack.size() - 1) return false;
    beginResetModel();
    std::swap(m_stack[row], m_stack[row + 1]);
    endResetModel();
    return true;
}

bool RpnStackModel::setValueAt(int row, const QString &text)
{
    if (row < 0 || row >= m_stack.size()) return false;

    bool ok = false;
    double v = parseInput(text, &ok);
    if (!ok) return false;

    m_stack[row] = v;
    emit dataChanged(index(row), index(row), { ValueRole });
    return true;
}
