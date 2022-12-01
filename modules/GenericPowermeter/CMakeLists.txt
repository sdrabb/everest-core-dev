#
# AUTO GENERATED - MARKED REGIONS WILL BE KEPT
# template version 3
#

# module setup:
#   - ${MODULE_NAME}: module name
ev_setup_cpp_module()

# ev@bcc62523-e22b-41d7-ba2f-825b493a3c97:v1
# insert your custom targets and additional config variables here
set(GENERIC_POWERMETER_MODEL_CONFIG_PATH "${CMAKE_INSTALL_PREFIX}/libexec/everest/modules/${MODULE_NAME}/models/")
configure_file(path_config.hpp.in path_config.hpp)

add_custom_command(TARGET ${MODULE_NAME} PRE_BUILD
                    COMMAND ${CMAKE_COMMAND} -E copy_directory
                    ${CMAKE_CURRENT_SOURCE_DIR}/models/ 
                    ${CMAKE_INSTALL_PREFIX}/libexec/everest/modules/${MODULE_NAME}/models/)
# ev@bcc62523-e22b-41d7-ba2f-825b493a3c97:v1

target_sources(${MODULE_NAME}
    PRIVATE
        "main/powermeterImpl.cpp"
)

# ev@c55432ab-152c-45a9-9d2e-7281d50c69c3:v1
# insert other things like install cmds etc here
target_link_libraries(${MODULE_NAME} PRIVATE everest::framework)

include_directories(${CMAKE_CURRENT_BINARY_DIR})
# ev@c55432ab-152c-45a9-9d2e-7281d50c69c3:v1
