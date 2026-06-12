cmake_minimum_required(VERSION 3.16)

get_filename_component(APP_RFDC_REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(APP_RFDC_DEFAULT_TOOLCHAIN_FILE
    "${APP_RFDC_REPO_ROOT}/buildroot-xilinx/output/t510-fnic/host/share/buildroot/toolchainfile.cmake")

if(NOT DEFINED CMAKE_TOOLCHAIN_FILE AND EXISTS "${APP_RFDC_DEFAULT_TOOLCHAIN_FILE}")
    set(CMAKE_TOOLCHAIN_FILE "${APP_RFDC_DEFAULT_TOOLCHAIN_FILE}" CACHE FILEPATH
        "Default Buildroot toolchain for T510_FNIC" FORCE)
endif()

project(t510_fnic_rfdc C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

set(APP_RFDC_SOURCES
    app_mailbox.c
    app_gpio.c
    main.c
    rfdc_platform.c
    lmk04828/lmk04828.c
    xrfdc/xrfdc.c
    xrfdc/xrfdc_ap.c
    xrfdc/xrfdc_clock.c
    xrfdc/xrfdc_dp.c
    xrfdc/xrfdc_intr.c
    xrfdc/xrfdc_mb.c
    xrfdc/xrfdc_mixer.c
    xrfdc/xrfdc_mts.c
)

add_executable(t510-fnic-rfdc ${APP_RFDC_SOURCES})

target_compile_options(t510-fnic-rfdc PRIVATE -O2 -Wall -Wextra)

target_include_directories(t510-fnic-rfdc
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/lmk04828
        ${CMAKE_CURRENT_SOURCE_DIR}/xrfdc
)

if(CMAKE_SYSROOT OR CMAKE_SYSTEM_NAME STREQUAL "Buildroot")
    target_include_directories(t510-fnic-rfdc SYSTEM PRIVATE "${CMAKE_SYSROOT}/usr/include")
    find_library(LIBMETAL_LIB
        NAMES metal
        PATHS "${CMAKE_SYSROOT}/usr/lib" "${CMAKE_SYSROOT}/lib"
        NO_DEFAULT_PATH
        REQUIRED
    )
else()
    find_library(LIBMETAL_LIB NAMES metal)
    if(NOT LIBMETAL_LIB)
        message(FATAL_ERROR
            "libmetal not found in host environment.\n"
            "This project is intended to be built with the Buildroot cross toolchain.\n"
            "Use:\n"
            "  cmake -S board/t510-fnic/app_rfdc -B board/t510-fnic/app_rfdc/build\n"
            "or simply:\n"
            "  make -C board/t510-fnic/app_rfdc\n"
            "If this build directory was previously configured for host gcc,\n"
            "remove build/CMakeCache.txt or delete the whole build directory first.")
    endif()
endif()

target_link_libraries(t510-fnic-rfdc PRIVATE "${LIBMETAL_LIB}" m)

if(CMAKE_STRIP)
    add_custom_command(
        TARGET t510-fnic-rfdc
        POST_BUILD
        COMMAND "${CMAKE_STRIP}" --strip-unneeded "$<TARGET_FILE:t510-fnic-rfdc>"
        VERBATIM
    )
endif()
