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
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY canUndoChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY canRedoChanged)
    Q_PROPERTY(QString decimalSeparator READ decimalSeparator CONSTANT)
    
    int formatMode() const { return m_formatMode; }
    int precision() const { return m_precision; }
    QString historyText() const { return m_historyText; }
    
public:
    explicit RpnEngine(QObject *parent = nullptr);

    RpnStackModel* stackModel() { return &m_model; }
    RpnHistoryModel* historyModel() { return &m_history; }

    Q_INVOKABLE bool enter(const QString &text);

    // Binarne
    Q_INVOKABLE void add();
    Q_INVOKABLE void sub();
    Q_INVOKABLE void mul();
    Q_INVOKABLE void div();
    Q_INVOKABLE void pow();
    Q_INVOKABLE void root(); // Nowość: pierwiastek n-tego stopnia

    // Unarne / Funkcje
    Q_INVOKABLE void sin();
    Q_INVOKABLE void cos();
    Q_INVOKABLE void neg();
    Q_INVOKABLE void reciprocal(); // Nowość: 1/x

    // Stack ops
    Q_INVOKABLE void dup();
    Q_INVOKABLE void drop();
    Q_INVOKABLE void clearAll();

    // Const
    Q_INVOKABLE void pushPi();
    Q_INVOKABLE void pushE();

    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    bool canUndo() const { return !m_undoStack.isEmpty(); }
    bool canRedo() const { return !m_redoStack.isEmpty(); }

    Q_INVOKABLE void saveSessionState() const;
    Q_INVOKABLE void loadSessionState();
    QString topAsString() const;

    QString decimalSeparator() const { return QLocale::system().decimalPoint(); }

    Q_INVOKABLE bool modifyStackValue(int row, const QString &text);

signals:
    void errorOccurred(const QString &message);
    void formatModeChanged();
    void precisionChanged();
    void historyTextChanged();
    void canUndoChanged();
    void canRedoChanged();

public slots:
    void setFormatMode(int mode);
    void setPrecision(int p);

private:
    RpnStackModel m_model;
    RpnHistoryModel m_history;
    QString m_historyText;
    
    int m_formatMode = RpnStackModel::Simple;
    int m_precision  = 15;
    
    bool require(int n);
    void error(const QString &msg);
    bool pop2(double &a, double &b);
    void appendHistoryLine(const QString &line);

    // Undo/Redo
    void saveState(); 
    struct EngineState {
        QVector<double> stack;
        QString historyText;
    };
    EngineState captureState() const;
    void restoreState(const EngineState& s);
    QVector<EngineState> m_undoStack;
    QVector<EngineState> m_redoStack;
};