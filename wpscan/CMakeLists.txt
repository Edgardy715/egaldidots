cmake_minimum_required(VERSION 3.22)
project(Wpscan LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Concurrent Qml)

qt6_add_qml_module(wpscanplugin
    URI "Wpscan"
    VERSION 1.0
    SOURCES
        WallpaperScanner.cpp
        WallpaperScanner.h
)

target_link_libraries(wpscanplugin PRIVATE
    Qt6::Core Qt6::Gui Qt6::Concurrent Qt6::Qml
)