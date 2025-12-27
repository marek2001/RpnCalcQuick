#include "rpnengine.h"

#include <QtMath>
#include <QLocale>
#include <cmath>

// Pomocnicze: ładne logowanie wyniku (TOP)
QString RpnEngine::topAsString() const
{
    if (!m_model.has(1)) return QStringLiteral("-");
    return m_model.data(m_model.index(0), RpnStackModel::ValueRole).toString();
}

RpnEngine::RpnEngine(QObject *parent) : QObject(parent) {
    m_model.setNumberFormat(m_formatMode, m_precision);
}

// ==========================================
// SEKCJA UNDO / REDO / STATE
// ==========================================

void RpnEngine::saveState()
{
    // Zapisz obecny stan na stos undo
    m_undoStack.push_back(m_model.snapshot());

    // Każda nowa akcja czyści możliwość Redo (historia alternatywna przepada)
    if (!m_redoStack.isEmpty()) {
        m_redoStack.clear();
        emit canRedoChanged();
    }

    // Ogranicz rozmiar historii (np. do 100 kroków)
    if (m_undoStack.size() > 100)
        m_undoStack.removeFirst();

    emit canUndoChanged();
}

void RpnEngine::undo()
{
    if (m_undoStack.isEmpty()) return;

    // 1. Zapisz obecny stan na stos Redo (zanim go nadpiszemy)
    m_redoStack.push_back(m_model.snapshot());

    // 2. Pobierz ostatni stan z Undo
    QVector<double> prevState = m_undoStack.takeLast();

    // 3. Przywróć model
    m_model.restore(prevState);

    // 4. Odśwież UI i logi
    emit canUndoChanged();
    emit canRedoChanged();
    appendHistoryLine("--- undo ---");
}

void RpnEngine::redo()
{
    if (m_redoStack.isEmpty()) return;

    // 1. Zapisz obecny stan na Undo
    m_undoStack.push_back(m_model.snapshot());

    // 2. Pobierz stan z Redo
    QVector<double> nextState = m_redoStack.takeLast();

    // 3. Przywróć model
    m_model.restore(nextState);

    // 4. Odśwież UI i logi
    emit canUndoChanged();
    emit canRedoChanged();
    appendHistoryLine("--- redo ---");
}

// ==========================================
// HISTORIA TEKSTOWA I BŁĘDY
// ==========================================

void RpnEngine::appendHistoryLine(const QString &line)
{
    if (m_historyText.isEmpty()) {
        m_historyText = line;
    } else {
        // Najnowszy wpis na górze
        m_historyText = line + '\n' + m_historyText;
    }
    emit historyTextChanged();
}

void RpnEngine::clearHistory()
{
    m_history.clear(); 
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

// ==========================================
// OPERACJE GŁÓWNE
// ==========================================

bool RpnEngine::enter(const QString &text)
{
    bool ok = false;
    const double v = RpnStackModel::parseInput(text, &ok);

    if (!ok) {
        if (!text.trimmed().isEmpty()) {
            error("Nieprawidłowa liczba.");
        }
        return false;
    }

    // ZAPIS STANU PRZED ZMIANĄ
    saveState();

    m_model.push(v);
    appendHistoryLine(QString("push %1").arg(text.trimmed()));
    return true;
}

// ----- BINARNE -----

void RpnEngine::add()
{
    if (!require(2)) return; // Sprawdzamy wymogi PRZED zapisem stanu
    saveState();             // ZAPIS

    double a,b; 
    pop2(a,b); // To już nie powinno zawieść, bo sprawdziliśmy require(2)
    m_model.push(a + b);
    
    appendHistoryLine(QString("%1 %2 + -> %3")
        .arg(QString::number(a, 'g', 15))
        .arg(QString::number(b, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::sub()
{
    if (!require(2)) return;
    saveState();

    double a,b; 
    pop2(a,b);
    m_model.push(a - b);

    appendHistoryLine(QString("%1 %2 - -> %3")
        .arg(QString::number(a, 'g', 15))
        .arg(QString::number(b, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::mul()
{
    if (!require(2)) return;
    saveState();

    double a,b; 
    pop2(a,b);
    m_model.push(a * b);

    appendHistoryLine(QString("%1 %2 * -> %3")
        .arg(QString::number(a, 'g', 15))
        .arg(QString::number(b, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::div()
{
    if (!require(2)) return;
    saveState();

    double a,b; 
    pop2(a,b);

    if (b == 0.0) {
        // Przywracamy ręcznie wartości na stos, żeby nie stracić danych
        m_model.push(a);
        m_model.push(b);
        
        // Ponieważ operacja się nie udała (stan stosu jest taki sam jak przed saveState),
        // usuwamy ostatni zapis z Undo, żeby nie tworzyć pustego kroku.
        if (!m_undoStack.isEmpty()) m_undoStack.removeLast();
        emit canUndoChanged();

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
    if (!require(2)) return;
    saveState();

    double a,b; 
    pop2(a,b);
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
    saveState();

    double x; 
    m_model.pop(x);

    if (x < 0.0) {
        m_model.push(x); // przywracamy
        
        // Cofamy saveState, bo błąd
        if (!m_undoStack.isEmpty()) m_undoStack.removeLast();
        emit canUndoChanged();

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
    saveState();

    double x; 
    m_model.pop(x);
    m_model.push(std::sin(x));
    
    appendHistoryLine(QString("sin(%1) -> %2")
        .arg(QString::number(x, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::cos()
{
    if (!require(1)) return;
    saveState();

    double x; 
    m_model.pop(x);
    m_model.push(std::cos(x));

    appendHistoryLine(QString("cos(%1) -> %2")
        .arg(QString::number(x, 'g', 15))
        .arg(topAsString()));
}

void RpnEngine::neg()
{
    if (!require(1)) return;
    saveState();

    double x; 
    m_model.pop(x);
    m_model.push(-x);

    appendHistoryLine(QString("neg(%1) -> %2")
        .arg(QString::number(x, 'g', 15))
        .arg(topAsString()));
}

// ----- STOS -----

void RpnEngine::dup()
{
    // RpnStackModel::dupTop sprawdza czy stos nie jest pusty, 
    // ale musimy to sprawdzić przed saveState, żeby nie robić pustych zapisów.
    if (!m_model.has(1)) { error("Nie ma czego zduplikować."); return; }
    
    saveState();
    m_model.dupTop();
    appendHistoryLine(QString("dup -> %1").arg(topAsString()));
}

void RpnEngine::swap()
{
    if (!m_model.has(2)) { error("Swap wymaga 2 elementów."); return; }

    saveState();
    m_model.swapTop();
    appendHistoryLine("swap");
}

void RpnEngine::drop()
{
    if (!m_model.has(1)) { error("Nie ma czego usunąć."); return; }

    saveState();
    m_model.dropTop();
    appendHistoryLine("drop");
}

void RpnEngine::clearAll()
{
    // Jeśli stos jest pusty, nic nie robimy i nie zapisujemy stanu
    if (!m_model.has(1)) return;

    saveState();
    m_model.clearAll();
    appendHistoryLine("clear");
}

// ----- STAŁE -----

void RpnEngine::pushPi()
{
    saveState();
    m_model.push(M_PI);
    appendHistoryLine(QString("push pi -> %1").arg(topAsString()));
}

void RpnEngine::pushE()
{
    saveState();
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

    // nie resetuj precyzji, tylko odśwież formatowanie
    m_model.setNumberFormat(m_formatMode, m_precision);
}

void RpnEngine::setPrecision(int p)
{
    if (p < 0) p = 0;
    if (p > 17) p = 17;
    if (m_precision == p) return;

    m_precision = p;
    emit precisionChanged();

    m_model.setNumberFormat(m_formatMode, m_precision);
}