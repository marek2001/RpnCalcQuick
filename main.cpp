#include <QApplication>
#include <QQmlApplicationEngine>
#include <QtQml/qqml.h>

#include <QtQuickControls2/QQuickStyle>

#include "rpnengine.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    
    QQuickStyle::setStyle("org.kde.desktop");
    QGuiApplication::setDesktopFileName("org.mar.RpnCalc");
    QCoreApplication::setOrganizationName("marek2001");
    QCoreApplication::setApplicationName("RpnCalcQuick");
    qmlRegisterType<RpnEngine>("RpnCalc.Backend", 1, 0, "RpnEngine");

    QQmlApplicationEngine engine;
    engine.loadFromModule("RpnCalc", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
