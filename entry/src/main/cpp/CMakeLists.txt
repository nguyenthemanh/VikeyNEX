cmake_minimum_required(VERSION 3.16)
project(vikey LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# The dictionary headers are large. Optimise even debug builds so the compile stays tractable.
set(CMAKE_CXX_FLAGS_DEBUG "-O2 -g")
set(CMAKE_CXX_FLAGS_RELEASE "-O2")

set(ENGINE ${CMAKE_CURRENT_SOURCE_DIR}/../../../../Engine)

add_library(vikey SHARED
    napi_init.cpp
    ${ENGINE}/Engine.cpp
    ${ENGINE}/Vietnamese.cpp
    ${ENGINE}/SmartSwitchKey.cpp
    ${ENGINE}/Driver.cpp
    ${ENGINE}/TouchModel.cpp)

target_include_directories(vikey PRIVATE ${ENGINE} ${ENGINE}/platforms)
target_compile_options(vikey PRIVATE -w -O2 -fvisibility=hidden -Wno-deprecated-declarations)
target_link_libraries(vikey PUBLIC libace_napi.z.so libhilog_ndk.z.so)
