file(GLOB INTERFACE_FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/*.json
)

execute_process(
    COMMAND
        ${EV_CLI} interface generate-sources --framework-dir ${everest-framework_SOURCE_DIR} --output-dir ${GENERATED_OUTPUT_DIR}
    WORKING_DIRECTORY
        ${PROJECT_SOURCE_DIR}
)

set(GENERATED_INTERFACE_DIR ${GENERATED_OUTPUT_DIR}/src/interface)

function(make_interface_target_available INTERFACE_NAME INTERFACE_TYPE)
    set (INTERFACE_TARGET interface_${INTERFACE_NAME}_${INTERFACE_TYPE})
    add_library(
        ${INTERFACE_TARGET}
        OBJECT EXCLUDE_FROM_ALL
        ${GENERATED_INTERFACE_DIR}/${INTERFACE_NAME}_${INTERFACE_TYPE}.cpp
        ${GENERATED_INTERFACE_DIR}/${INTERFACE_NAME}_json.cpp
    )
    target_include_directories(${INTERFACE_TARGET}
        PRIVATE
        ${GENERATED_OUTPUT_DIR}/include
    )
    target_link_libraries(
        ${INTERFACE_TARGET}
        PRIVATE
            everest
            everest::log
    )
endfunction()

foreach(INTERFACE_FILE ${INTERFACE_FILES})
    get_filename_component(INTERFACE_NAME ${INTERFACE_FILE} NAME_WLE)
    make_interface_target_available(${INTERFACE_NAME} req)
    make_interface_target_available(${INTERFACE_NAME} impl)
endforeach()
