set (EV_STAGE_DIR ${CMAKE_BINARY_DIR}/ev-stage)
set (EV_STAGE_MODULE_DIR ${EV_STAGE_DIR}/modules)
set (EV_STAGE_MANIFEST_DIR ${EV_STAGE_MODULE_DIR}/manifests)
set (EV_SYMBOLIC_LINKED_JS_MODULES "")
set (EV_GENERATED_OUTPUT_DIR ${CMAKE_BINARY_DIR}/generated)

file (MAKE_DIRECTORY ${EV_STAGE_MODULE_DIR})
file (MAKE_DIRECTORY ${EV_STAGE_MANIFEST_DIR})

add_custom_target(ev_setup_stage ALL
    COMMAND
        ${CMAKE_COMMAND} -E create_symlink $<TARGET_FILE:manager>  $<TARGET_FILE_NAME:manager>
    WORKING_DIRECTORY
        ${EV_STAGE_DIR}
)

set_property(
    TARGET
        ev_setup_stage
    APPEND
    PROPERTY
        ADDITIONAL_CLEAN_FILES ${EV_STAGE_DIR}/$<TARGET_FILE_NAME:manager>
)

include(EverestTypeLayer/setup)
