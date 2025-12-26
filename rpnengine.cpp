#include "rpnengine.h"

#include <QtMath>
#include <QLocale>
#include <cmath>

// pomocnicze: ładne logowanie wyniku (TOP) – używa aktualnego formatu z modelu stosu
QString RpnEngine::topAsString() const
{
    if (!m_model.has(1)) return QStringLiteral("-");
    return m_model.data(m_model.index(0), RpnStackModel::ValueRole).toString();
}

RpnEngine::RpnEngine(QObject *parent) : QObject(parent) {
    m_model.setNumberFormat(m_formatMode, m_precision);
}

void RpnEngine::appendHistoryLine(const QString &line)
{
    if (!m_historyText.isEmpty())
        m_historyText += '\n';
    m_historyText += line;
    emit historyTextChanged();
}

void RpnEngine::clearHistory()
{
    m_historyText.clear();
    emit historyTextChanged();
}

void RpnEngine::error(const QString &msg)
{
    appendHistoryLine(QString("ERR: %1").arg(msg));
    emit errorOccurred(msg);
}

bool RpnEngine::require(int n)
{
    if (!m_model.has(n)) {
        error(QString("Za mało argumentów na stosie (potrzeba %1).").arg(n));
        return false;
    }
    return true;
}

bool RpnEngine::pop2(double &a, double &b)
{
    if (!require(2)) return false;
    // TOP jest na 0, więc najpierw b=top, potem a=kolejny
    if (!m_model.pop(b)) return false;
    if (!m_model.pop(a)) return false;
    return true;
}

// [plik: rpnengine.cpp]

// ...

bool RpnEngine::enter(const QString &text)
{
    // STARA WERSJA (do usunięcia/zastąpienia):
    /*
    QString t = text.trimmed();
    if (t.isEmpty()) return false;
    t.replace(',', '.');
    bool ok = false;
    const double v = QLocale::c().toDouble(t, &ok);
    */

    // NOWA WERSJA:
    bool ok = false;
    const double v = RpnStackModel::parseInput(text, &ok);

    if (!ok) {
        // Pusty ciąg ignorujemy (false, ale bez błędu), 
        // błędny ciąg zgłaszamy jako error.
        if (!text.trimmed().isEmpty()) {
            error("Nieprawidłowa liczba.");
        }
        return false;
    }

    m_model.push(v);
    appendHistoryLine(QString("push %1").arg(text.trimmed())); // logujemy to co wpisał użytkownik
    return true;
}

// ...

// ----- BINARNE -----

void RpnEngine::add()
{
    double a,b; if (!pop2(a,b)) return;
    m_model.push(a + b);
    appendHistoryLine(QString("%1 %2 + -> %3")
        .arg(QString::number(a, 'g', 15))
        .arg(QString::number(b, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::sub()
{
    double a,b; if (!pop2(a,b)) return;
    m_model.push(a - b);
    appendHistoryLine(QString("%1 %2 - -> %3")
        .arg(QString::number(a, 'g', 15))
        .arg(QString::number(b, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::mul()
{
    double a,b; if (!pop2(a,b)) return;
    m_model.push(a * b);
    appendHistoryLine(QString("%1 %2 * -> %3")
        .arg(QString::number(a, 'g', 15))
        .arg(QString::number(b, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::div()
{
    double a,b; if (!pop2(a,b)) return;
    if (b == 0.0) {
        // przywróć, bo to RPN i użytkownik nie chce utraty danych
        m_model.push(a);
        m_model.push(b);
        error("Dzielenie przez zero.");
        return;
    }
    m_model.push(a / b);
    appendHistoryLine(QString("%1 %2 / -> %3")
        .arg(QString::number(a, 'g', 15))
        .arg(QString::number(b, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::pow()
{
    double a,b; if (!pop2(a,b)) return;
    m_model.push(std::pow(a, b));
    appendHistoryLine(QString("%1 %2 pow -> %3")
        .arg(QString::number(a, 'g', 15))
        .arg(QString::number(b, 'g', 15))
        .arg(topAsString()));
}

// ----- UNARNE -----

void RpnEngine::sqrt()
{
    if (!require(1)) return;
    double x; m_model.pop(x);
    if (x < 0.0) {
        m_model.push(x);
        error("sqrt dla liczby ujemnej.");
        return;
    }
    m_model.push(std::sqrt(x));
    appendHistoryLine(QString("sqrt(%1) -> %2")
        .arg(QString::number(x, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::sin()
{
    if (!require(1)) return;
    double x; m_model.pop(x);
    m_model.push(std::sin(x)); // radiany
    appendHistoryLine(QString("sin(%1) -> %2")
        .arg(QString::number(x, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::cos()
{
    if (!require(1)) return;
    double x; m_model.pop(x);
    m_model.push(std::cos(x)); // radiany
    appendHistoryLine(QString("cos(%1) -> %2")
        .arg(QString::number(x, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::neg()
{
    if (!require(1)) return;
    double x; m_model.pop(x);
    m_model.push(-x);
    appendHistoryLine(QString("neg(%1) -> %2")
        .arg(QString::number(x, 'g', 15))
        .arg(topAsString()));
}

// ----- STOS -----

void RpnEngine::dup()
{
    if (!m_model.dupTop()) { error("Nie ma czego zduplikować."); return; }
    appendHistoryLine(QString("dup -> %1").arg(topAsString()));
}

void RpnEngine::swap()
{
    if (!m_model.swapTop()) { error("Swap wymaga 2 elementów."); return; }
    appendHistoryLine("swap");
}

void RpnEngine::drop()
{
    if (!m_model.dropTop()) { error("Nie ma czego usunąć."); return; }
    appendHistoryLine("drop");
}

void RpnEngine::clearAll()
{
    m_model.clearAll();
    appendHistoryLine("clear");
}

// ----- STAŁE -----

void RpnEngine::pushPi()
{
    m_model.push(M_PI);
    appendHistoryLine(QString("push pi -> %1").arg(topAsString()));
}

void RpnEngine::pushE()
{
    m_model.push(M_E);
    appendHistoryLine(QString("push e -> %1").arg(topAsString()));
}

// ----- FORMAT -----

void RpnEngine::setFormatMode(int mode)
{
    if (mode < 0 || mode > 2) return;
    if (m_formatMode == mode) return;

    m_formatMode = mode;
    emit formatModeChanged();

    // nie resetuj precyzji
    m_model.setNumberFormat(m_formatMode, m_precision);

    // NIE zapisujemy zmiany notacji w historii
}

void RpnEngine::setPrecision(int p)
{
    if (p < 0) p = 0;
    if (p > 17) p = 17;
    if (m_precision == p) return;

    m_precision = p;
    emit precisionChanged();

    m_model.setNumberFormat(m_formatMode, m_precision);

    // NIE zapisujemy zmiany precyzji w historii
}
