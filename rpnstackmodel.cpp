#include "rpnstackmodel.h"

#include <QLocale>
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
    return {
        { ValueRole, "value" }
    };
}

QString RpnStackModel::toSuperscript(int n)
{
    static const QChar supDigits[] = {
        QChar(0x2070), // ⁰
        QChar(0x00B9), // ¹
        QChar(0x00B2), // ²
        QChar(0x00B3), // ³
        QChar(0x2074), // ⁴
        QChar(0x2075), // ⁵
        QChar(0x2076), // ⁶
        QChar(0x2077), // ⁷
        QChar(0x2078), // ⁸
        QChar(0x2079)  // ⁹
    };

    if (n == 0)
        return QString(supDigits[0]);

    QString out;
    if (n < 0) {
        out += QChar(0x207B); // ⁻
        n = -n;
    }

    const QString digits = QString::number(n);
    for (QChar c : digits)
        out += supDigits[c.unicode() - '0'];

    return out;
}

QString RpnStackModel::formatValue(double v) const
{
    if (!std::isfinite(v))
        return QStringLiteral("NaN");

    if (v == 0.0)
        return QStringLiteral("0");

    const double absV = std::abs(v);

    switch (m_mode) {
    case Scientific: {
        int exp = static_cast<int>(std::floor(std::log10(absV)));
        double mant = v / std::pow(10.0, exp);

        // m_precision = cyfry znaczące
        const QString mantStr = QString::number(mant, 'g', m_precision);
        return QString("%1 * 10^%2").arg(mantStr).arg(exp);
    }

    case Engineering: {
        int exp = static_cast<int>(std::floor(std::log10(absV)));
        exp = (exp / 3) * 3;
        double mant = v / std::pow(10.0, exp);

        const QString mantStr = QString::number(mant, 'g', m_precision);
        return QString("%1 * 10^%2").arg(mantStr).arg(exp);
    }

    case Simple:
    default:
        // zwykły zapis, bez wymuszonych zer
        return QString::number(v, 'g', 15);
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
    if (precision < 1) precision = 1;
    if (precision > 17) precision = 17;

    const auto newMode = static_cast<NumberFormat>(mode);
    const bool changed = (newMode != m_mode) || (precision != m_precision);

    m_mode = newMode;
    m_precision = precision;

    if (changed && !m_stack.isEmpty())
        emit dataChanged(index(0), index(m_stack.size() - 1), { ValueRole });
}

// ===== stack operations (engine) =====

bool RpnStackModel::has(int n) const
{
    return m_stack.size() >= n;
}

void RpnStackModel::push(double v)
{
    beginInsertRows(QModelIndex(), 0, 0);
    m_stack.prepend(v);
    endInsertRows();
}

bool RpnStackModel::pop(double &v)
{
    if (m_stack.isEmpty())
        return false;

    beginRemoveRows(QModelIndex(), 0, 0);
    v = m_stack.takeFirst();
    endRemoveRows();
    return true;
}

bool RpnStackModel::dupTop()
{
    if (m_stack.isEmpty())
        return false;

    beginInsertRows(QModelIndex(), 0, 0);
    m_stack.prepend(m_stack.first());
    endInsertRows();
    return true;
}

bool RpnStackModel::swapTop()
{
    if (m_stack.size() < 2)
        return false;

    beginResetModel();
    std::swap(m_stack[0], m_stack[1]);
    endResetModel();
    return true;
}

bool RpnStackModel::dropTop()
{
    if (m_stack.isEmpty())
        return false;

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

// ===== QML helpers =====

void RpnStackModel::removeAt(int row)
{
    if (row < 0 || row >= m_stack.size())
        return;

    beginRemoveRows(QModelIndex(), row, row);
    m_stack.removeAt(row);
    endRemoveRows();
}

bool RpnStackModel::moveUp(int row)
{
    if (row <= 0 || row >= m_stack.size())
        return false;

    beginResetModel();
    std::swap(m_stack[row], m_stack[row - 1]);
    endResetModel();
    return true;
}

bool RpnStackModel::moveDown(int row)
{
    if (row < 0 || row >= m_stack.size() - 1)
        return false;

    beginResetModel();
    std::swap(m_stack[row], m_stack[row + 1]);
    endResetModel();
    return true;
}

bool RpnStackModel::setValueAt(int row, const QString &text)
{
    if (row < 0 || row >= m_stack.size())
        return false;

    QString t = text.trimmed();
    if (t.isEmpty())
        return false;

    // ujednolicenia
    t.replace(',', '.');
    t.remove(' ');

    bool ok = false;
    double v = 0.0;

    // Obsługa formatu: a*10^b  (np. 3.2*10^5)
    const int star = t.indexOf('*');
    const int ten = t.indexOf("10^");
    if (star > 0 && ten > star) {
        const QString aStr = t.left(star);
        const QString bStr = t.mid(ten + 3); // po "10^"

        bool okA=false, okB=false;
        const double a = QLocale::c().toDouble(aStr, &okA);
        const int b = bStr.toInt(&okB);

        if (!okA || !okB) return false;
        v = a * std::pow(10.0, b);
        ok = std::isfinite(v);
    } else {
        // Obsługa: 3.2e5 / zwykła liczba
        v = QLocale::c().toDouble(t, &ok);
        ok = ok && std::isfinite(v);
    }

    if (!ok) return false;

    m_stack[row] = v;
    emit dataChanged(index(row), index(row), { ValueRole });
    return true;
}

