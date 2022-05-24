# search for ev-cli tool
find_program(EV_CLI
    ev-cli
    REQUIRED
)

if (NOT DEFINED EV_GENERATED_OUTPUT_DIR)
    message(FATAL_ERROR "The variable EV_GENERATED_OUTPUT_DIR needs to be set before including EcCli.cmake")
endif()

# FIXME (aw): some of the scripts in here do not really relate to ev-cli

function(ev_add_generate_interface_target INTERFACE_NAME)
    set(GENERATED_INTERFACE_SRC_DIR ${EV_GENERATED_OUTPUT_DIR}/src/interface)
    set(GENERATED_INTERFACE_HDR_DIR ${EV_GENERATED_OUTPUT_DIR}/include/generated/interface)

    set (INTERFACE_GENERATE_TARGET generate_interface_${INTERFACE_NAME})

    add_custom_command(
        COMMENT
            "Generating source files for interface '${INTERFACE_NAME}'"
        OUTPUT
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_req.cpp
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_impl.cpp
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_def.cpp
            ${GENERATED_INTERFACE_HDR_DIR}/${INTERFACE_NAME}_req.hpp
            ${GENERATED_INTERFACE_HDR_DIR}/${INTERFACE_NAME}_impl.hpp
        DEPENDS
            ${INTERFACE_NAME}.json
        COMMAND
            ${EV_CLI} interface generate-sources --framework-dir ${everest-framework_SOURCE_DIR} --output-dir ${EV_GENERATED_OUTPUT_DIR} --force ${INTERFACE_NAME}
        WORKING_DIRECTORY
            ${PROJECT_SOURCE_DIR}
    )

    add_custom_target(${INTERFACE_GENERATE_TARGET}
        DEPENDS
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_req.cpp
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_impl.cpp
            ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_def.cpp
            ${GENERATED_INTERFACE_HDR_DIR}/${INTERFACE_NAME}_req.hpp
            ${GENERATED_INTERFACE_HDR_DIR}/${INTERFACE_NAME}_impl.hpp
    )


endfunction()

function(ev_make_interface_target_available INTERFACE_NAME INTERFACE_TYPE)
    set(GENERATED_INTERFACE_SRC_DIR ${EV_GENERATED_OUTPUT_DIR}/src/interface)
    set(GENERATED_INTERFACE_HDR_DIR ${EV_GENERATED_OUTPUT_DIR}/include/generated/interface)

    set (INTERFACE_TARGET interface_${INTERFACE_NAME}_${INTERFACE_TYPE})

    set (INTERFACE_GENERATE_TARGET generate_interface_${INTERFACE_NAME})

    add_library(
        ${INTERFACE_TARGET}
        OBJECT EXCLUDE_FROM_ALL
        ${GENERATED_INTERFACE_SRC_DIR}/${INTERFACE_NAME}_${INTERFACE_TYPE}.cpp
    )

    add_dependencies(${INTERFACE_TARGET} ${INTERFACE_GENERATE_TARGET})

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

function(ev_setup_cpp_module)
    set(GENERATED_MODULE_SRC_DIR ${EV_GENERATED_OUTPUT_DIR}/src/module)
    set(GENERATED_MODULE_HDR_DIR ${EV_GENERATED_OUTPUT_DIR}/include/generated/module)

    get_filename_component(MODULE_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    list (APPEND EV_NEEDED_INTERFACES ${MODULE_NAME})
    set(MODULE_TARGET module_${MODULE_NAME})
    set(MODULE_LOADER_DIR ${GENERATED_MODULE_SRC_DIR}/${MODULE_NAME})

    add_executable(${MODULE_TARGET})
    set_target_properties(${MODULE_TARGET} PROPERTIES OUTPUT_NAME ${MODULE_NAME})

    set(MODULE_CMAKE_DIRECTIVES ${MODULE_LOADER_DIR}/mod_deps.cmake)
    if ((NOT EXISTS ${MODULE_CMAKE_DIRECTIVES}) OR (${CMAKE_CURRENT_SOURCE_DIR}/manifest.json IS_NEWER_THAN ${MODULE_CMAKE_DIRECTIVES}))
        execute_process(
            COMMAND
                ${EV_CLI} module generate-sources --framework-dir ${everest-framework_SOURCE_DIR} --output-dir ${EV_GENERATED_OUTPUT_DIR} --force ${MODULE_NAME}
            WORKING_DIRECTORY
                ${PROJECT_SOURCE_DIR}
        )
    endif()

    # this populates ${MODULE_REQUIREMENTS} and ${MODULE_IMPLEMENTATIONS}
    include(${MODULE_CMAKE_DIRECTIVES})
    foreach(REQUIREMENT ${MODULE_REQUIREMENTS})
        # ev_make_interface_target_available(${REQUIREMENT} req)
        add_dependencies(${MODULE_TARGET} interface_${REQUIREMENT}_req)
        target_link_libraries(${MODULE_TARGET}
            PRIVATE
                interface_${REQUIREMENT}_req
                interface_${REQUIREMENT}_def
        )
    endforeach()

    foreach(IMPLEMENTATION ${MODULE_IMPLEMENTATIONS})
        # ev_make_interface_target_available(${IMPLEMENTATION} impl)
        add_dependencies(${MODULE_TARGET} interface_${IMPLEMENTATION}_impl)
        target_link_libraries(${MODULE_TARGET}
            PRIVATE
                interface_${IMPLEMENTATION}_impl
                interface_${IMPLEMENTATION}_def
        )
    endforeach()

    set_property(
        DIRECTORY
        APPEND PROPERTY
        CMAKE_CONFIGURE_DEPENDS
            manifest.json
    )

    target_include_directories(${MODULE_TARGET} PRIVATE ${EV_GENERATED_OUTPUT_DIR}/include)
    target_sources(${MODULE_TARGET}
        PRIVATE
        ${MODULE_LOADER_DIR}/ld-ev.cpp
        ${MODULE_LOADER_DIR}/manifest.cpp
    )
    target_compile_features(${MODULE_TARGET} PRIVATE cxx_std_14)
    target_link_libraries(${MODULE_TARGET}
        PRIVATE
            everest ${CMAKE_DL_LIBS}
            everest::log
    )

    set(MODULE_TARGET ${MODULE_TARGET} PARENT_SCOPE)

    set(MODULE_DEST "modules/${MODULE_NAME}")

    set(EV_CURRENT_MODULE_STAGE_DIR ${EV_MODULE_STAGE_DIR}/${MODULE_NAME})
    file (MAKE_DIRECTORY ${EV_CURRENT_MODULE_STAGE_DIR})
    file (CREATE_LINK ${CMAKE_CURRENT_BINARY_DIR}/${MODULE_NAME} ${EV_CURRENT_MODULE_STAGE_DIR}/${MODULE_NAME} SYMBOLIC)
    file (CREATE_LINK ${CMAKE_CURRENT_SOURCE_DIR}/manifest.json ${EV_CURRENT_MODULE_STAGE_DIR}/manifest.json SYMBOLIC)

    install(TARGETS ${MODULE_TARGET}
        DESTINATION ${MODULE_DEST}
    )

    install(FILES manifest.json
        DESTINATION ${MODULE_DEST}
    )
endfunction()

function(ev_setup_js_module)
    get_filename_component(JS_MODULE_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)

    set (JS_MODULE_PACKAGE_DIR ${EV_MODULE_STAGE_DIR}/${JS_MODULE_NAME})

    if (${JS_MODULE_NAME} IN_LIST EV_SYMBOLIC_LINKED_JS_MODULES OR EV_SYMBOLIC_LINKED_JS_MODULES STREQUAL "ALL")
        if (NOT IS_SYMLINK ${JS_MODULE_PACKAGE_DIR} AND IS_DIRECTORY ${JS_MODULE_PACKAGE_DIR})
            # remove if real directory
            # FIXME (aw): should these commands be checked, so we do only safe deleting?
            file(REMOVE_RECURSE ${JS_MODULE_PACKAGE_DIR})
        endif ()

        file (CREATE_LINK ${CMAKE_CURRENT_SOURCE_DIR} ${JS_MODULE_PACKAGE_DIR} SYMBOLIC)
    else()
        if (IS_SYMLINK ${JS_MODULE_PACKAGE_DIR})
            file(REMOVE_RECURSE ${JS_MODULE_PACKAGE_DIR})
        endif ()
        file (MAKE_DIRECTORY ${JS_MODULE_PACKAGE_DIR})

        add_custom_target(rsync_check_${JS_MODULE_NAME}
            COMMAND
                rsync -ai --delete --exclude='node_modules' --exclude='CMakeLists.txt' --exclude='dist' ${CMAKE_CURRENT_SOURCE_DIR}/ ${JS_MODULE_PACKAGE_DIR}/ | grep . -q && touch ${CMAKE_CURRENT_BINARY_DIR}/.last_rsync_ts || true
        )

        add_custom_command(
            OUTPUT
                ${JS_MODULE_PACKAGE_DIR}/package.json  .last_rsync_ts
            DEPENDS
                rsync_check_${JS_MODULE_NAME}
        )

        add_custom_command(
            COMMENT
                "Running npm install for javascript module ${JS_MODULE_NAME}"
            OUTPUT
                .npm_install_done
            COMMAND
                npm install --no-save $<TARGET_FILE_DIR:everestjs>/package > ${CMAKE_CURRENT_BINARY_DIR}/.npm_install_log 2>&1 || (cat ${CMAKE_CURRENT_BINARY_DIR}/.npm_install_log; false)
            COMMAND
                touch ${CMAKE_CURRENT_BINARY_DIR}/.npm_install_done
            DEPENDS
                ${JS_MODULE_PACKAGE_DIR}/package.json
                everestjs_package
            WORKING_DIRECTORY
                ${JS_MODULE_PACKAGE_DIR}
        )

        # needs to be figured out
        add_custom_command(
            COMMENT
                "Building npm package for javascript module ${JS_MODULE_NAME}"
            OUTPUT
                .npm_package_done
            COMMAND
                npm run-script build > ${CMAKE_CURRENT_BINARY_DIR}/.npm_package_log 2>&1 || (cat ${CMAKE_CURRENT_BINARY_DIR}/.npm_package_log; false)
            COMMAND
                touch ${CMAKE_CURRENT_BINARY_DIR}/.npm_package_done
            DEPENDS
                .npm_install_done .last_rsync_ts
            WORKING_DIRECTORY
                ${JS_MODULE_PACKAGE_DIR}
        )

        set (EV_PACKAGE_JS_MODULE_TARGET ev_package_${JS_MODULE_NAME})
        add_custom_target(${EV_PACKAGE_JS_MODULE_TARGET}
            DEPENDS
                .npm_package_done
        )

        add_dependencies(ev_setup_stage ${EV_PACKAGE_JS_MODULE_TARGET})
    endif()
endfunction()
