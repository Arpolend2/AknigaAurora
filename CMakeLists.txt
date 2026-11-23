cmake_minimum_required(VERSION 3.12)
project(AknigaAurora LANGUAGES CXX)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX /usr CACHE PATH "Install prefix" FORCE)
endif()

set(APP_ID ru.arpolend.akniga)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)

find_package(Qt5 COMPONENTS Core Gui Qml Quick REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(AURORA REQUIRED auroraapp)
pkg_check_modules(WEBVIEW REQUIRED aurorawebview)

add_executable(${APP_ID} main.cpp akniga.qrc)
target_include_directories(${APP_ID} PRIVATE ${AURORA_INCLUDE_DIRS} ${WEBVIEW_INCLUDE_DIRS})
target_link_libraries(${APP_ID} PRIVATE Qt5::Quick ${AURORA_LDFLAGS} ${WEBVIEW_LDFLAGS})

install(TARGETS ${APP_ID} RUNTIME DESTINATION bin)
install(FILES ${APP_ID}.desktop DESTINATION share/applications)
install(FILES ${APP_ID}.svg DESTINATION share/icons/hicolor/scalable/apps)
foreach(size 86 108 128 172)
    install(FILES icons/${size}x${size}/apps/${APP_ID}.png
        DESTINATION share/icons/hicolor/${size}x${size}/apps)
endforeach()

add_custom_target(project_files SOURCES
    ${APP_ID}.desktop
    rpm/${APP_ID}.spec
    AknigaWindow.qml
    Main.qml
    ${APP_ID}.svg)

file(WRITE "${CMAKE_BINARY_DIR}/QtCreatorDeployment.txt"
    "${CMAKE_INSTALL_PREFIX}\n${CMAKE_BINARY_DIR}/${APP_ID}:bin\n"
    "${CMAKE_SOURCE_DIR}/${APP_ID}.desktop:share/applications\n"
    "${CMAKE_SOURCE_DIR}/${APP_ID}.svg:share/icons/hicolor/scalable/apps\n")
foreach(size 86 108 128 172)
    file(APPEND "${CMAKE_BINARY_DIR}/QtCreatorDeployment.txt"
        "${CMAKE_SOURCE_DIR}/icons/${size}x${size}/apps/${APP_ID}.png:share/icons/hicolor/${size}x${size}/apps\n")
endforeach()
