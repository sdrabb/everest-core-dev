file(GLOB INTERFACE_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/*.json
)

foreach(INTERFACE_FILE ${INTERFACE_FILES})
    get_filename_component(INTERFACE_NAME ${INTERFACE_FILE} NAME_WLE)
    ev_add_generate_interface_target(${INTERFACE_NAME})
    ev_make_interface_target_available(${INTERFACE_NAME} req)
    ev_make_interface_target_available(${INTERFACE_NAME} impl)
    ev_make_interface_target_available(${INTERFACE_NAME} def)
endforeach()
