function (_ev_add_generate_interface_target_cpp INTERFACE_NAME)

    set (GENERATE_INTERFACE_TARGET generate_interface_${INTERFACE_NAME}_cpp)
    set (GENERATED_INTERFACE_SRC_DIR ${EV_GENERATED_OUTPUT_DIR}/src/interface)
    set (GENERATED_INTERFACE_HDR_DIR ${EV_GENERATED_OUTPUT_DIR}/include/generated/interface)

    add_custom_command(
        COMMENT
            "Generating c++ source files for interface '${INTERFACE_NAME}'"
        OUTPUT
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_req.cpp
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_impl.cpp
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_def.cpp
            ${GENERATED_INTERFACE_HDR_DIR}/${INTERFACE_NAME}_req.hpp
            ${GENERATED_INTERFACE_HDR_DIR}/${INTERFACE_NAME}_impl.hpp
        DEPENDS
            ${INTERFACE_NAME}.json
        COMMAND
            ${EV_CLI} interface generate-sources --framework-dir ${everest-framework_SOURCE_DIR} --output-dir ${EV_GENERATED_OUTPUT_DIR} ${INTERFACE_NAME} > /dev/null
        WORKING_DIRECTORY
            ${PROJECT_SOURCE_DIR}
    )

    add_custom_target(${GENERATE_INTERFACE_TARGET}
        DEPENDS
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_req.cpp
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_impl.cpp
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_def.cpp
            ${GENERATED_INTERFACE_HDR_DIR}/${INTERFACE_NAME}_req.hpp
            ${GENERATED_INTERFACE_HDR_DIR}/${INTERFACE_NAME}_impl.hpp
    )

endfunction ()


function(_ev_add_interface_target_cpp INTERFACE_NAME INTERFACE_TYPE)

    set(GENERATED_INTERFACE_SRC_DIR ${EV_GENERATED_OUTPUT_DIR}/src/interface)
    set(GENERATED_INTERFACE_HDR_DIR ${EV_GENERATED_OUTPUT_DIR}/include/generated/interface)

    set (INTERFACE_TARGET interface_${INTERFACE_NAME}.${INTERFACE_TYPE}_cpp)

    add_library(
        ${INTERFACE_TARGET}
        OBJECT EXCLUDE_FROM_ALL
        ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_${INTERFACE_TYPE}.cpp
    )

    add_dependencies(${INTERFACE_TARGET} generate_interface_${INTERFACE_NAME}_cpp)

    target_include_directories(${INTERFACE_TARGET}
        PRIVATE
        ${EV_GENERATED_OUTPUT_DIR}/include
    )

    target_link_libraries(
        ${INTERFACE_TARGET}
        PRIVATE
            everest
            everest::log
    )

endfunction()


function (_ev_add_module_target_cpp ${MODULE_NAME})

    set(GENERATED_MODULE_SRC_DIR ${EV_GENERATED_OUTPUT_DIR}/src/module)
    set(GENERATED_MODULE_HDR_DIR ${EV_GENERATED_OUTPUT_DIR}/include/generated/module)

    set(MODULE_TARGET module_${MODULE_NAME})
    set(MODULE_LOADER_DIR ${GENERATED_MODULE_SRC_DIR}/${MODULE_NAME})
    
    add_custom_command(
        COMMENT
            "Generating c++ source files for module '${MODULE_NAME}'"
        OUTPUT
            ${MODULE_LOADER_DIR}/ld-ev.cpp
            ${MODULE_LOADER_DIR}/manifest.cpp
            ${GENERATED_MODULE_HDR_DIR}/${MODULE_NAME}.hpp
        COMMAND
            ${EV_CLI} module generate-sources --framework-dir ${everest-framework_SOURCE_DIR} --output-dir ${EV_GENERATED_OUTPUT_DIR} ${MODULE_NAME} > /dev/null
        WORKING_DIRECTORY
            ${PROJECT_SOURCE_DIR}
    )

    add_executable(${MODULE_TARGET}
        ${MODULE_LOADER_DIR}/ld-ev.cpp
        ${MODULE_LOADER_DIR}/manifest.cpp
    )
    set_target_properties(${MODULE_TARGET} PROPERTIES OUTPUT_NAME ${MODULE_NAME})
    target_include_directories(${MODULE_TARGET} PRIVATE ${EV_GENERATED_OUTPUT_DIR}/include)
    target_compile_features(${MODULE_TARGET} PRIVATE cxx_std_14)
    target_link_libraries(${MODULE_TARGET}
        PRIVATE
            everest ${CMAKE_DL_LIBS}
            everest::log
    )

    set (MODULE_DEPENDENCIES_FILE ${CMAKE_CURRENT_BINARY_DIR}/mod_deps.cmake)
    include(${MODULE_DEPENDENCIES_FILE})

    foreach(REQUIREMENT ${MODULE_REQUIRES})
        target_link_libraries(${MODULE_TARGET}
            PRIVATE
                interface_${REQUIREMENT}.req_cpp
                interface_${REQUIREMENT}.def_cpp
        )
    endforeach()

    foreach(IMPLEMENTATION ${MODULE_IMPLEMENTS})
        target_link_libraries(${MODULE_TARGET}
            PRIVATE
                interface_${IMPLEMENTATION}.impl_cpp
                interface_${IMPLEMENTATION}.def_cpp
        )
    endforeach()

    set(MODULE_TARGET ${MODULE_TARGET} PARENT_SCOPE)

endfunction ()


function(ev_setup_cpp_module)

    get_filename_component(MODULE_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)

    _ev_add_module_target_cpp(${MODULE_NAME})

    set(MODULE_TARGET ${MODULE_TARGET} PARENT_SCOPE)

    set(MODULE_DEST "modules/${MODULE_NAME}")

    set(EV_CURRENT_MODULE_STAGE_DIR ${EV_STAGE_MODULE_DIR}/${MODULE_NAME})
    file (MAKE_DIRECTORY ${EV_CURRENT_MODULE_STAGE_DIR})
    file (CREATE_LINK ${CMAKE_CURRENT_BINARY_DIR}/${MODULE_NAME} ${EV_CURRENT_MODULE_STAGE_DIR}/${MODULE_NAME} SYMBOLIC)

    add_custom_command (
        COMMENT
            "Setting up stage symlink for module ${MODULE_NAME}"
        OUTPUT
            ${EV_CURRENT_MODULE_STAGE_DIR}/${MODULE_NAME}
        COMMAND
            ${CMAKE_COMMAND} -E create_symlink $<TARGET_FILE:${MODULE_TARGET}>  $<TARGET_FILE_NAME:${MODULE_TARGET}>
        WORKING_DIRECTORY
            ${EV_CURRENT_MODULE_STAGE_DIR}
    )

    add_custom_target (module_${MODULE_NAME}_stage_link
        DEPENDS
            ${EV_CURRENT_MODULE_STAGE_DIR}/${MODULE_NAME}
    )

    add_dependencies (ev_setup_stage module_${MODULE_NAME}_stage_link)

    install(TARGETS ${MODULE_TARGET}
        DESTINATION ${MODULE_DEST}
    )

    install(FILES manifest.json
        DESTINATION ${MODULE_DEST}
    )

endfunction()
