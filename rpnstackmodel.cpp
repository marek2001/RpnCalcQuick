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

    const QLocale loc = QLocale::system();

    // Usuń typowe separatory grupowania
    t.remove(' ');
    t.remove(QChar(0x00A0));        // NBSP (często jako separator tysięcy)
    t.remove(loc.groupSeparator()); // separator grupowania wg locale
    t.remove('\'');                 // czasem apostrof (np. CH)

    // Normalizuj separator dziesiętny: akceptuj zarówno '.' jak i ','
    const QChar dec = loc.decimalPoint().isEmpty() ? QChar('.') : loc.decimalPoint().at(0);
    if (dec == ',')
        t.replace('.', ',');
    else
        t.replace(',', '.');

    double v = 0.0;
    bool status = false;

    // Obsługa a*10^b
    const int splitIdx = t.indexOf("*10^");
    if (const int splitIdx = t.indexOf("*10^"); splitIdx > 0) {
        const QString aStr = t.left(splitIdx);
        const QString bStr = t.mid(splitIdx + 4);

        // ZAMIAST ręcznego liczenia: v = a * std::pow(10.0, b);
        // Tworzymy standardowy ciąg naukowy (np. "1.23E5") i parsujemy go w całości.
        // Dzięki temu unikamy błędu mnożenia floatów.
        
        QString scientificStr = aStr + "E" + bStr;
        
        v = QLocale::c().toDouble(scientificStr, &status);
        
        if (status) {
            status = std::isfinite(v);
        }
    } else {
        v = loc.toDouble(t, &status);
        if (status) status = std::isfinite(v);
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
    const QChar dec = loc.decimalPoint().isEmpty() ? QChar('.') : loc.decimalPoint().at(0);

    auto cleanZerosLocale = [&](QString s) -> QString {
        if (s.contains(dec)) {
            while (s.endsWith('0')) s.chop(1);
            if (s.endsWith(dec)) s.chop(1);
        }
        return s;
    };

    switch (m_mode) {
        case Scientific: {
            int exp = static_cast<int>(std::floor(std::log10(absV)));
            double mant = v / std::pow(10.0, exp);

            QString mantStr = cleanZerosLocale(loc.toString(mant, 'f', m_precision));
            return QString("%1 * 10^%2").arg(mantStr).arg(exp);
        }
        case Engineering: {
            int exp = static_cast<int>(std::floor(std::log10(absV)));
            exp = (exp / 3) * 3;
            double mant = v / std::pow(10.0, exp);

            QString mantStr = cleanZerosLocale(loc.toString(mant, 'f', m_precision));
            return QString("%1 * 10^%2").arg(mantStr).arg(exp);
        }
        case Simple:
        default: {
            // Simple: zawsze bez notacji naukowej + grupowanie wg locale
            const int fracDigits = qBound(0, m_precision, 17); // albo stałe np. 12
            QString s = loc.toString(v, 'f', fracDigits);

            s = cleanZerosLocale(s);

            if (s == QStringLiteral("-0"))
                s = QStringLiteral("0");

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
