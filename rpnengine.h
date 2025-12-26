#pragma once
#include <QObject>

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

    // unarne
    Q_INVOKABLE void sqrt();
    Q_INVOKABLE void sin();
    Q_INVOKABLE void cos();
    Q_INVOKABLE void neg();

    // stack ops
    Q_INVOKABLE void dup();
    Q_INVOKABLE void swap();
    Q_INVOKABLE void drop();
    Q_INVOKABLE void clearAll();

    // const
    Q_INVOKABLE void pushPi();
    Q_INVOKABLE void pushE();

    Q_INVOKABLE void clearHistory();

    RpnHistoryModel* historyModel() { return &m_history; }
    QString topAsString() const;



    signals:
        void errorOccurred(const QString &message);
        void formatModeChanged();
        void precisionChanged();
        void historyTextChanged();
    public slots:
        void setFormatMode(int mode);
        void setPrecision(int p);

    

private:
    RpnStackModel m_model;
    int m_formatMode = RpnStackModel::Simple;
    int m_precision  = 9;
    bool require(int n);
    void error(const QString &msg);

    bool pop2(double &a, double &b); // a=drugi (X1), b=top (X0)

    void applyNumberStyle();
    RpnHistoryModel m_history;
    QString m_historyText;
    void appendHistoryLine(const QString &line);

    

    
};


