#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtQml/qqml.h>
#include "rpnengine.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    qmlRegisterType<RpnEngine>("RpnCalc.Backend", 1, 0, "RpnEngine");

    QQmlApplicationEngine engine;
    engine.loadFromModule("RpnCalc", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
