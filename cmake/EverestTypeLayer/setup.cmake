# search for ev-cli tool
find_program(EV_CLI
    ev-cli
)

if (NOT EV_CLI)
    message (FATAL_ERROR "Could not find the 'ev-cli' tool.  It is available from the 'everest-utils' package")
endif ()

if (NOT DEFINED EV_GENERATED_OUTPUT_DIR)
    message(FATAL_ERROR "The variable EV_GENERATED_OUTPUT_DIR needs to be set before including '${CMAKE_CURRENT_LIST_FILE}'")
endif()

set_property (GLOBAL PROPERTY everest_required_interfaces "")

include(${CMAKE_CURRENT_LIST_DIR}/CPP.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/JS.cmake)

function(_ev_add_generate_interface_target INTERFACE_NAME)
    
    _ev_add_generate_interface_target_cpp(${INTERFACE_NAME})
    _ev_add_generate_interface_target_ts(${INTERFACE_NAME})

endfunction()


function (ev_add_interface_target INTERFACE_NAME)

    # first the generate targets
    _ev_add_generate_interface_target(${INTERFACE_NAME})

    # then the "compiling" targets
    _ev_add_interface_target_cpp(${INTERFACE_NAME} req)
    _ev_add_interface_target_cpp(${INTERFACE_NAME} impl)
    _ev_add_interface_target_cpp(${INTERFACE_NAME} def)

    _ev_add_interface_target_ts(${INTERFACE_NAME})

endfunction ()


function (ev_register_module MODULE_NAME)

    file (MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/${MODULE_NAME})
    set(MODULE_MANIFEST_FILE ${CMAKE_CURRENT_SOURCE_DIR}/${MODULE_NAME}/manifest.json)

    set(MODULE_DEPENDENCIES_FILE ${CMAKE_CURRENT_BINARY_DIR}/${MODULE_NAME}/mod_deps.cmake)
    if ((NOT EXISTS ${MODULE_DEPENDENCIES_FILE}) OR (${MODULE_MANIFEST_FILE} IS_NEWER_THAN ${MODULE_DEPENDENCIES_FILE}))
        execute_process(
            COMMAND
                ${EV_CLI} module generate-cmake --framework-dir ${everest-framework_SOURCE_DIR} --output-dir ${CMAKE_CURRENT_BINARY_DIR}/${MODULE_NAME} ${MODULE_NAME}
            WORKING_DIRECTORY
                ${PROJECT_SOURCE_DIR}
            OUTPUT_QUIET
        )
    endif()

    set_property(
        DIRECTORY
        APPEND PROPERTY
        CMAKE_CONFIGURE_DEPENDS
            ${MODULE_MANIFEST_FILE}
    )
    
    get_property (REQUIRED_INTERFACES GLOBAL PROPERTY everest_required_interfaces)

    include(${MODULE_DEPENDENCIES_FILE})
    foreach(REQUIREMENT ${MODULE_REQUIRES})
        if (NOT REQUIREMENT IN_LIST REQUIRED_INTERFACES)
            list (APPEND REQUIRED_INTERFACES ${REQUIREMENT})
        endif ()
    endforeach()
    foreach(IMPLEMENTATION ${MODULE_IMPLEMENTS})
        if (NOT IMPLEMENTATION IN_LIST REQUIRED_INTERFACES)
            list (APPEND REQUIRED_INTERFACES ${IMPLEMENTATION})
        endif ()
    endforeach()

    set_property (GLOBAL PROPERTY everest_required_interfaces ${REQUIRED_INTERFACES})

    add_custom_command(
        COMMENT
            "Copying manifest for module '${MODULE_NAME}' to ev-stage"
        OUTPUT
            ${EV_STAGE_MANIFEST_DIR}/${MODULE_NAME}.json
        COMMAND
            ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/${MODULE_NAME}/manifest.json ${EV_STAGE_MANIFEST_DIR}/${MODULE_NAME}.json
        DEPENDS
            ${CMAKE_CURRENT_SOURCE_DIR}/${MODULE_NAME}/manifest.json
    )
    set (STAGE_MANIFEST_TARGET module_${MODULE_NAME}_stage_manifest)
    add_custom_target(module_${MODULE_NAME}_stage_manifest
        DEPENDS
            ${EV_STAGE_MANIFEST_DIR}/${MODULE_NAME}.json
    )
    add_dependencies(ev_setup_stage ${STAGE_MANIFEST_TARGET})

    # NOTE (aw): add_module_target_ts reuses the MODULE_IMPLEMENTS and MODULE_REQUIRES list
    _ev_add_module_target_ts(${MODULE_NAME})
    
endfunction()
