#include "rpnengine.h"
#include <QLocale>
#include <cmath>
#include <QSettings>

QString RpnEngine::topAsString() const
{
    if (!m_model.has(1)) return QStringLiteral("-");
    return m_model.data(m_model.index(0), RpnStackModel::ValueRole).toString();
}

RpnEngine::RpnEngine(QObject *parent) : QObject(parent) {
    m_model.setNumberFormat(m_formatMode, m_precision);
}

// --- HISTORY & ERRORS ---

void RpnEngine::appendHistoryLine(const QString &line)
{
    if (m_historyText.isEmpty()) {
        m_historyText = line;
    } else {
        // Najnowsze na górze
        m_historyText = line + '\n' + m_historyText;
    }
    emit historyTextChanged();
}

void RpnEngine::clearHistory()
{
    if (m_historyText.isEmpty()) return; 
    saveState();
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
    if (!m_model.pop(b)) return false;
    if (!m_model.pop(a)) return false;
    return true;
}

// --- CORE OPS ---

bool RpnEngine::enter(const QString &text)
{
    bool ok = false;
    // Używamy zunifikowanego parsera
    const double v = RpnStackModel::parseInput(text, &ok);

    if (!ok) {
        if (!text.trimmed().isEmpty()) {
            error("Nieprawidłowa liczba.");
        }
        return false;
    }
    
    saveState();
    m_model.push(v);
    appendHistoryLine(QString("push %1").arg(text.trimmed()));
    return true;
}

void RpnEngine::add()
{
    if (!require(2)) return;
    saveState();
    double a,b; pop2(a,b); 
    m_model.push(a + b);
    appendHistoryLine(QString("%1 %2 + -> %3").arg(a).arg(b).arg(topAsString()));
}

void RpnEngine::sub()
{
    if (!require(2)) return;
    saveState();
    double a,b; pop2(a,b);
    m_model.push(a - b);
    appendHistoryLine(QString("%1 %2 - -> %3").arg(a).arg(b).arg(topAsString()));
}

void RpnEngine::mul()
{
    if (!require(2)) return;
    saveState();
    double a,b; pop2(a,b);
    m_model.push(a * b);
    appendHistoryLine(QString("%1 %2 * -> %3").arg(a).arg(b).arg(topAsString()));
}

void RpnEngine::div()
{
    if (!require(2)) return;
    saveState();
    double a,b; pop2(a,b);
    if (b == 0.0) {
        m_model.push(a); m_model.push(b);
        if (!m_undoStack.isEmpty()) m_undoStack.removeLast();
        emit canUndoChanged();
        error("Dzielenie przez zero.");
        return;
    }
    m_model.push(a / b);
    appendHistoryLine(QString("%1 %2 / -> %3").arg(a).arg(b).arg(topAsString()));
}

void RpnEngine::pow()
{
    if (!require(2)) return;
    saveState();
    double a,b; pop2(a,b);
    m_model.push(std::pow(a, b));
    appendHistoryLine(QString("%1 %2 pow -> %3").arg(a).arg(b).arg(topAsString()));
}

void RpnEngine::root()
{
    if (!require(2)) return;
    saveState();
    double base, degree; 
    pop2(base, degree); 

    if (degree == 0.0) {
        m_model.push(base); m_model.push(degree);
        if (!m_undoStack.isEmpty()) m_undoStack.removeLast();
        emit canUndoChanged();
        error("Stopień pierwiastka 0.");
        return;
    }
    double result = std::pow(base, 1.0 / degree);
    if (!std::isfinite(result)) {
        m_model.push(base); m_model.push(degree);
        if (!m_undoStack.isEmpty()) m_undoStack.removeLast();
        emit canUndoChanged();
        error("Błędny wynik pierwiastkowania.");
        return;
    }

    m_model.push(result);
    appendHistoryLine(QString("%2 root %1 -> %3").arg(base).arg(degree).arg(topAsString()));
}

void RpnEngine::sin()
{
    if (!require(1)) return;
    saveState();
    double x; m_model.pop(x);
    m_model.push(std::sin(x));
    appendHistoryLine(QString("sin(%1) -> %2").arg(x).arg(topAsString()));
}

void RpnEngine::cos()
{
    if (!require(1)) return;
    saveState();
    double x; m_model.pop(x);
    m_model.push(std::cos(x));
    appendHistoryLine(QString("cos(%1) -> %2").arg(x).arg(topAsString()));
}

void RpnEngine::neg()
{
    if (!require(1)) return;
    saveState();
    double x; m_model.pop(x);
    m_model.push(-x);
    appendHistoryLine(QString("neg(%1) -> %2").arg(x).arg(topAsString()));
}

void RpnEngine::reciprocal()
{
    if (!require(1)) return;
    
    // Check 0 before saveState logic? 
    // Usually saveState first, then logic. But let's check first to avoid bad states.
    // However, to be safe:
    saveState();
    double x; m_model.pop(x);
    
    if (x == 0.0) {
        m_model.push(x);
        if (!m_undoStack.isEmpty()) m_undoStack.removeLast();
        emit canUndoChanged();
        error("Dzielenie przez zero (1/x).");
        return;
    }
    m_model.push(1.0 / x);
    appendHistoryLine(QString("1/%1 -> %2").arg(x).arg(topAsString()));
}

void RpnEngine::dup()
{
    if (!m_model.has(1)) { error("Pusty stos (dup)."); return; }
    saveState();
    m_model.dupTop();
    appendHistoryLine(QString("dup -> %1").arg(topAsString()));
}

void RpnEngine::drop()
{
    if (!m_model.has(1)) { error("Pusty stos (drop)."); return; }
    saveState();
    m_model.dropTop();
    appendHistoryLine("drop");
}

void RpnEngine::clearAll()
{
    if (!m_model.has(1)) return;
    saveState();
    m_model.clearAll();
    appendHistoryLine("clear");
}

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

// --- STATE & SETTINGS ---

void RpnEngine::setFormatMode(int mode)
{
    if (mode < 0 || mode > 2) return;
    if (m_formatMode == mode) return;
    m_formatMode = mode;
    emit formatModeChanged();
    m_model.setNumberFormat(m_formatMode, m_precision);
}

void RpnEngine::setPrecision(int p)
{
    if (p < 0) p = 0; else if (p > 17) p = 17;
    if (m_precision == p) return;
    m_precision = p;
    emit precisionChanged();
    m_model.setNumberFormat(m_formatMode, m_precision);
}

void RpnEngine::saveState()
{
    m_undoStack.push_back(captureState());
    if (!m_redoStack.isEmpty()) {
        m_redoStack.clear();
        emit canRedoChanged();
    }
    if (m_undoStack.size() > 100) m_undoStack.removeFirst();
    emit canUndoChanged();
}

void RpnEngine::undo()
{
    if (m_undoStack.isEmpty()) return;
    m_redoStack.push_back(captureState());
    restoreState(m_undoStack.takeLast());
    emit canUndoChanged();
    emit canRedoChanged();
}

void RpnEngine::redo()
{
    if (m_redoStack.isEmpty()) return;
    m_undoStack.push_back(captureState());
    restoreState(m_redoStack.takeLast());
    emit canUndoChanged();
    emit canRedoChanged();
}

RpnEngine::EngineState RpnEngine::captureState() const
{
    return { m_model.snapshot(), m_historyText };
}

void RpnEngine::restoreState(const EngineState &s)
{
    m_model.restore(s.stack);
    m_historyText = s.historyText;
    emit historyTextChanged();
}

void RpnEngine::saveSessionState() const
{
    QSettings s("marek2001", "RpnCalcQuick");
    const QVector<double> snap = m_model.snapshot();
    QVariantList list;
    for (double v : snap) list.push_back(v);
    s.setValue("session/stack", list);
    s.setValue("session/historyText", m_historyText);
    s.setValue("session/formatMode", m_formatMode);
    s.setValue("session/precision", m_precision);
}

void RpnEngine::loadSessionState()
{
    QSettings s("marek2001", "RpnCalcQuick");
    setFormatMode(s.value("session/formatMode", m_formatMode).toInt());
    setPrecision(s.value("session/precision", m_precision).toInt());

    const QVariantList list = s.value("session/stack").toList();
    QVector<double> snap;
    for (const QVariant &item : list) snap.push_back(item.toDouble());
    m_model.restore(snap);

    m_historyText = s.value("session/historyText", "").toString();
    emit historyTextChanged();
}