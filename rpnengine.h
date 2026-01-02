#pragma once
#include <QObject>
#include <QList>
#include <QLocale>

#include "rpnstackmodel.h"
#include "rpnhistorymodel.h"

class RpnEngine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(RpnStackModel* stackModel READ stackModel CONSTANT)
    Q_PROPERTY(int formatMode READ formatMode WRITE setFormatMode NOTIFY formatModeChanged)
    Q_PROPERTY(int precision READ precision WRITE setPrecision NOTIFY precisionChanged)
    Q_PROPERTY(RpnHistoryModel* historyModel READ historyModel CONSTANT)
    Q_PROPERTY(QString historyText READ historyText NOTIFY historyTextChanged)

    // --- NOWE PROPERTY DLA UI ---
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY canUndoChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY canRedoChanged)
    // ----------------------------

    Q_PROPERTY(QString decimalSeparator READ decimalSeparator CONSTANT)
    
    int formatMode() const { return m_formatMode; }
    int precision() const { return m_precision; }
    QString historyText() const { return m_historyText; }
    
public:
    explicit RpnEngine(QObject *parent = nullptr);

    RpnStackModel* stackModel() { return &m_model; }

    Q_INVOKABLE bool enter(const QString &text);

    // binarne
    Q_INVOKABLE void add();
    Q_INVOKABLE void sub();
    Q_INVOKABLE void mul();
    Q_INVOKABLE void div();
    Q_INVOKABLE void pow();
    Q_INVOKABLE void root();

    // unarne
    //Q_INVOKABLE void sqrt();
    Q_INVOKABLE void sin();
    Q_INVOKABLE void cos();
    Q_INVOKABLE void neg();

    // stack ops
    Q_INVOKABLE void dup();
    Q_INVOKABLE void reciprocal();
    Q_INVOKABLE void drop();
    Q_INVOKABLE void clearAll();

    // const
    Q_INVOKABLE void pushPi();
    Q_INVOKABLE void pushE();

    Q_INVOKABLE void clearHistory();

    // --- NOWE METODY UNDO/REDO ---
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    bool canUndo() const { return !m_undoStack.isEmpty(); }
    bool canRedo() const { return !m_redoStack.isEmpty(); }
    // -----------------------------

    RpnHistoryModel* historyModel() { return &m_history; }
    QString topAsString() const;

    Q_INVOKABLE QString stackJson() const;
    Q_INVOKABLE void setStackJson(const QString &json);

    Q_INVOKABLE QString history() const;
    Q_INVOKABLE void setHistory(const QString &text);

    Q_INVOKABLE void saveSessionState() const;
    Q_INVOKABLE void loadSessionState();

    QString decimalSeparator() const { return QLocale::system().decimalPoint(); }

signals:
    void errorOccurred(const QString &message);
    void formatModeChanged();
    void precisionChanged();
    void historyTextChanged();
    
    // Sygnały zmiany stanu undo/redo
    void canUndoChanged();
    void canRedoChanged();

public slots:
    void setFormatMode(int mode);
    void setPrecision(int p);

private:
    RpnStackModel m_model;
    int m_formatMode = RpnStackModel::Simple;
    int m_precision  = 9;
    
    bool require(int n);
    void error(const QString &msg);
    bool pop2(double &a, double &b);

    RpnHistoryModel m_history;
    QString m_historyText;
    void appendHistoryLine(const QString &line);

    // --- HISTORIA STANÓW ---
    void saveState(); // Wywoływana przed modyfikacją
    struct EngineState {
        QVector<double> stack;
        QString historyText;
        // jeśli używasz m_history jako lista, możesz też dodać:
        // QStringList history;
    };

    EngineState captureState() const;
    void restoreState(const EngineState& s);

    QVector<EngineState> m_undoStack;
    QVector<EngineState> m_redoStack;
};