add_library(fsm-ng INTERFACE)
add_library(fsm::fsm-ng ALIAS fsm-ng)

target_include_directories(fsm-ng INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
