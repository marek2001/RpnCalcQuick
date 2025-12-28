#pragma once
#include <QAbstractListModel>
#include <QStringList>

class RpnHistoryModel final : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles { TextRole = Qt::UserRole + 1 };
    Q_ENUM(Roles)

    explicit RpnHistoryModel(QObject *parent = nullptr);
    ~RpnHistoryModel() override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override {
        if (parent.isValid()) return 0;
        return m_items.size();
    }

    QVariant data(const QModelIndex &index, int role) const override {
        if (!index.isValid()) return {};
        const int row = index.row();
        if (row < 0 || row >= m_items.size()) return {};
        if (role == TextRole) return m_items[row];
        return {};
    }

    QHash<int, QByteArray> roleNames() const override {
        return {{TextRole, "text"}};
    }

    Q_INVOKABLE void clear() {
        beginResetModel();
        m_items.clear();
        endResetModel();
    }

    void add(const QString &line) {
        const int row = m_items.size();
        beginInsertRows(QModelIndex(), row, row);
        m_items.push_back(line);
        endInsertRows();
    }

private:
    QStringList m_items;
};
