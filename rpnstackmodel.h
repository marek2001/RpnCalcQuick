#pragma once

#include <QAbstractListModel>
#include <QVector>

class RpnStackModel final : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Roles {
        ValueRole = Qt::UserRole + 1
    };
    Q_ENUM(Roles)

    enum NumberFormat {
        Scientific = 0,
        Engineering = 1,
        Simple = 2
    };
    Q_ENUM(NumberFormat)

    explicit RpnStackModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // engine API
    bool has(int n) const;
    void push(double v);
    bool pop(double &v);
    bool dupTop();
    bool swapTop();
    bool dropTop();
    void clearAll();

    // QML API
    Q_INVOKABLE void removeAt(int row);
    Q_INVOKABLE bool moveUp(int row);
    Q_INVOKABLE bool moveDown(int row);
    Q_INVOKABLE bool setValueAt(int row, const QString &text);

    static double parseInput(const QString &text, bool *ok = nullptr);
    
    // formatting
    void setNumberFormat(int mode, int precision);

private:
    QVector<double> m_stack; // TOP = index 0

    NumberFormat m_mode = Scientific;
    int m_precision = 6;

    QString formatValue(double v) const;

    static QString toSuperscript(int n);
};
