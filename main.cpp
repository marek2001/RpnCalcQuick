#include <QApplication>
#include <QQmlApplicationEngine>
#include <QtQml/qqml.h>
#include <QIcon>

#include <QtQuickControls2/QQuickStyle>

#include "rpnengine.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    
    // Set application icon
    app.setWindowIcon(QIcon(":/qt/qml/RpnCalc/icons/RpnCalcQuickIcon.svg"));
    
    QQuickStyle::setFallbackStyle("Fusion");
    QGuiApplication::setDesktopFileName("appRpnCalcQuick");
    QCoreApplication::setOrganizationName("marek2001");
    QCoreApplication::setApplicationName("RpnCalcQuick");
    QCoreApplication::setApplicationVersion("0.9.0");
    qmlRegisterType<RpnEngine>("RpnCalc.Backend", 0, 8, "RpnEngine");

    QQmlApplicationEngine engine;
    // engine.load(QUrl(QStringLiteral("qrc:/qt/qml/RpnCalc/Main.qml")));
    engine.loadFromModule("RpnCalc", "Main");


    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
