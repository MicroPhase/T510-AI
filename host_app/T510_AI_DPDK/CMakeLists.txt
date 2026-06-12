cmake_minimum_required(VERSION 3.11)
project(t510_ai_dpdk LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(T510_AI_ENABLE_ASAN "Build with AddressSanitizer" OFF)
option(T510_AI_ENABLE_UBSAN "Build with UndefinedBehaviorSanitizer" OFF)

set(T510_AI_SANITIZER_FLAGS "")
if (T510_AI_ENABLE_ASAN)
    list(APPEND T510_AI_SANITIZER_FLAGS -fsanitize=address -fno-omit-frame-pointer)
endif()
if (T510_AI_ENABLE_UBSAN)
    list(APPEND T510_AI_SANITIZER_FLAGS -fsanitize=undefined -fno-omit-frame-pointer)
endif()

find_package(Threads REQUIRED)
find_package(OpenGL REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(DPDK REQUIRED libdpdk)
pkg_check_modules(GLFW3 REQUIRED glfw3)
pkg_check_modules(GLEW REQUIRED glew)

set(IMGUI_DIR ${CMAKE_SOURCE_DIR}/gui/third_party/imgui)

add_library(t510_ai_dpdk STATIC
    src/core/zero_copy.cpp
    src/core/time_spec.cpp
    src/core/dpdk_zero_copy.cpp
    src/transport/local_ctrl.cpp
    src/device/t510_ai_rfdc_ctrl.cpp
    src/device/t510_ai_fpga_ctrl.cpp
    src/device/t510_ai_impl.cpp
    src/device/t510_ai_iq_payload.cpp
    src/device/t510_ai_dpdk_device.cpp
)

target_include_directories(t510_ai_dpdk PUBLIC
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
    ${DPDK_INCLUDE_DIRS}
)

target_link_directories(t510_ai_dpdk PUBLIC ${DPDK_LIBRARY_DIRS})
target_link_libraries(t510_ai_dpdk PUBLIC Threads::Threads ${DPDK_LIBRARIES})
target_compile_options(t510_ai_dpdk PUBLIC ${DPDK_CFLAGS_OTHER} -fPIC)
if (T510_AI_SANITIZER_FLAGS)
    target_compile_options(t510_ai_dpdk PUBLIC ${T510_AI_SANITIZER_FLAGS})
    target_link_options(t510_ai_dpdk PUBLIC ${T510_AI_SANITIZER_FLAGS})
endif()

add_executable(t510_ai_gui
    gui/src/t510_ai_gui.cpp
    gui/src/t510_ai_gui_support.cpp
    gui/src/t510_ai_gui_workers.cpp
    ${IMGUI_DIR}/imgui.cpp
    ${IMGUI_DIR}/imgui_draw.cpp
    ${IMGUI_DIR}/imgui_tables.cpp
    ${IMGUI_DIR}/imgui_widgets.cpp
    ${IMGUI_DIR}/backends/imgui_impl_glfw.cpp
    ${IMGUI_DIR}/backends/imgui_impl_opengl3.cpp
)

target_include_directories(t510_ai_gui PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
    ${IMGUI_DIR}
    ${IMGUI_DIR}/backends
    ${GLFW3_INCLUDE_DIRS}
    ${GLEW_INCLUDE_DIRS}
)

target_link_directories(t510_ai_gui PRIVATE
    ${GLFW3_LIBRARY_DIRS}
    ${GLEW_LIBRARY_DIRS}
)

target_link_libraries(t510_ai_gui PRIVATE
    t510_ai_dpdk
    OpenGL::GL
    ${GLFW3_LIBRARIES}
    ${GLEW_LIBRARIES}
    ${CMAKE_DL_LIBS}
)

target_compile_definitions(t510_ai_gui PRIVATE IMGUI_IMPL_OPENGL_LOADER_GLEW)
target_compile_options(t510_ai_gui PRIVATE ${GLFW3_CFLAGS_OTHER} ${GLEW_CFLAGS_OTHER})
if (T510_AI_SANITIZER_FLAGS)
    target_compile_options(t510_ai_gui PRIVATE ${T510_AI_SANITIZER_FLAGS})
    target_link_options(t510_ai_gui PRIVATE ${T510_AI_SANITIZER_FLAGS})
endif()
