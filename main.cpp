#include <QApplication>
#include <QQmlApplicationEngine>
#include <QtQml/qqml.h>

#include <QtQuickControls2/QQuickStyle>

#include "rpnengine.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    
    QQuickStyle::setFallbackStyle("Fusion");
    QGuiApplication::setDesktopFileName("org.mar.RpnCalc");
    QCoreApplication::setOrganizationName("marek2001");
    QCoreApplication::setApplicationName("RpnCalcQuick");
    qmlRegisterType<RpnEngine>("RpnCalc.Backend", 0, 6, "RpnEngine");

    QQmlApplicationEngine engine;
    engine.load(QUrl(u"qrc:/RpnCalc/Main.qml"_qs));
    // or qrc:/qt/qml/RpnCalc/Main.qml depending on your setup


    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
