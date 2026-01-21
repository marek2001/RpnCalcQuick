cmake_minimum_required(VERSION 3.21)
project(RpnCalcQuick VERSION 0.9.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Qml QuickControls2 Widgets)

qt_standard_project_setup()

# Set Qt policies with version checks
if(COMMAND qt_policy)
    qt_policy(SET QTP0001 NEW)
    
    # QTP0004 policy: qmldir files requirement
    # This policy exists in Qt 6.7+, check if it's available before setting
    if(Qt6_VERSION VERSION_GREATER_EQUAL "6.7.0")
        qt_policy(SET QTP0004 NEW)
    endif()
endif()

qt_add_executable(appRpnCalcQuick MANUAL_FINALIZATION
        main.cpp
        rpnengine.cpp
        rpnstackmodel.cpp
        rpnhistorymodel.cpp
        rpnhistorymodel.h
)

qt_add_qml_module(appRpnCalcQuick
        URI RpnCalc
        VERSION 0.9
        QML_FILES
        qml/Main.qml
        qml/MainForm.qml
        qml/InputHandler.qml
        qml/DisplayFormatter.qml
        qml/KeyboardController.qml
        qml/CommandDispatcher.qml
        RESOURCES
        icons/RpnCalcQuickIcon.svg
)

target_link_libraries(appRpnCalcQuick PRIVATE
        Qt6::Quick Qt6::Qml Qt6::QuickControls2 Qt6::Widgets
)

qt_import_qml_plugins(appRpnCalcQuick)

qt_finalize_executable(appRpnCalcQuick)



include(GNUInstallDirs)

install(TARGETS appRpnCalcQuick
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(FILES appRpnCalcQuick.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
        RENAME appRpnCalcQuick.desktop
)

install(FILES icons/RpnCalcQuickIcon.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
        RENAME appRpnCalcQuick.svg
)
