#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtQml/qqml.h>

#include <QtQuickControls2/QQuickStyle>   // <-- TO DODAJ

#include "rpnengine.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Ustaw styl ZANIM załadujesz QML (czyli przed engine.load...)
    QQuickStyle::setStyle("org.kde.desktop");  // albo "Breeze" jako fallback

    qmlRegisterType<RpnEngine>("RpnCalc.Backend", 1, 0, "RpnEngine");

    QQmlApplicationEngine engine;
    engine.loadFromModule("RpnCalc", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
