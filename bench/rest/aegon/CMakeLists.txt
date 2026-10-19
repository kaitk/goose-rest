cmake_minimum_required(VERSION 3.28)
project(rest_aegon LANGUAGES CXX)

# HttpArena's entry: C++26, -O3 -march=native, a Release build (NOTES.md).
set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()
add_compile_options(-O3 -march=native)

include(FetchContent)
# Aegon's install rules export its targets, which glaze as a subproject
# can't join; nothing here is installed.
set(CMAKE_SKIP_INSTALL_RULES ON)

# glaze at the version Arch Linux packages, which HttpArena's entry builds with.
FetchContent_Declare(glaze
    GIT_REPOSITORY https://github.com/stephenberry/glaze.git
    GIT_TAG v9.0.0
    GIT_SHALLOW TRUE
    EXCLUDE_FROM_ALL
    OVERRIDE_FIND_PACKAGE)

# Aegon finds ngtcp2 by its library's name, without its headers, so the
# prefix that holds the one bench/rest.sh builds comes first.
foreach(prefix ${CMAKE_PREFIX_PATH})
    include_directories(BEFORE SYSTEM ${prefix}/include)
endforeach()

set(AEGON_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(AEGON_BUILD_SAMPLES OFF CACHE BOOL "" FORCE)
set(AEGON_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
FetchContent_Declare(aegon
    GIT_REPOSITORY https://github.com/UdayKhare09/Aegon.git
    GIT_TAG 850005726096c02e586a2b987390b79575108f8f
    EXCLUDE_FROM_ALL)

FetchContent_MakeAvailable(glaze aegon)

find_library(JEMALLOC jemalloc REQUIRED)

set(SOURCES
    src/app.cpp
    src/arena.cpp
    src/snow.cpp
    src/heavy.cpp
    src/writes.cpp
    src/framework.cpp
    src/main.cpp)

# rest-aegon takes the entry's buffers for an unlimited memlock limit, and
# rest-aegon-small its buffers for a low one.
foreach(name rest-aegon rest-aegon-small)
    add_executable(${name} ${SOURCES})
    target_link_libraries(${name} PRIVATE Aegon::http Aegon::core glaze::glaze ${JEMALLOC})
endforeach()
target_compile_definitions(rest-aegon-small PRIVATE AEGON_SMALL=1)
