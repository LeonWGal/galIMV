#pragma once
#include <QObject>
#include <QGuiApplication>
#include <QIcon>
#include <QFile>
#include <QRegularExpression>

class AppIdentity : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE bool setAccent(const QString& key) {
        if (!QRegularExpression("^lobe-[a-z]+$").match(key).hasMatch()) return false;
        const QString path=":/galIMV/resources/accent-icons/"+key+".ico";
        if(!QFile::exists(path)) return false;
        const QIcon icon(path);
        if(icon.isNull()) return false;
        QGuiApplication::setWindowIcon(icon);
        return true;
    }
};
