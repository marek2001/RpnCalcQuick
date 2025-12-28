cmake_minimum_required(VERSION 3.21)
project(RpnCalcQuick LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.2 REQUIRED COMPONENTS Quick Qml)

qt_standard_project_setup()

qt_add_executable(appRpnCalcQuick
        main.cpp
        rpnengine.cpp
        rpnstackmodel.cpp
        rpnhistorymodel.h
)

qt_add_qml_module(appRpnCalcQuick
        URI RpnCalc
        VERSION 1.0
        QML_FILES
        qml/Main.qml
)
find_package(Qt6 REQUIRED COMPONENTS Quick Qml QuickControls2 Widgets)
target_link_libraries(appRpnCalcQuick PRIVATE Qt6::Quick Qt6::Qml Qt6::QuickControls2 Qt6::Widgets)
