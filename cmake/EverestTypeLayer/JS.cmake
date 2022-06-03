set (EV_JS_TYPE_LAYER_DIR ${EV_GENERATED_OUTPUT_DIR}/everestjs-type-layer)
set (EV_JS_TYPE_LAYER_DIST_DIR ${EV_JS_TYPE_LAYER_DIR}/lib)

function (_ev_add_generate_interface_target_ts INTERFACE_NAME)

    set (GENERATE_INTERFACE_TARGET generate_interface_${INTERFACE_NAME}_ts)
    set (GENERATED_INTERFACE_TS_DIR ${EV_JS_TYPE_LAYER_DIR}/src/interface)

    add_custom_command(
        COMMENT
            "Generating typescript source files for interface '${INTERFACE_NAME}'"
        OUTPUT
            ${GENERATED_INTERFACE_TS_DIR}/${INTERFACE_NAME}.ts
        DEPENDS
            ${INTERFACE_NAME}.json
        COMMAND
            ${EV_CLI} interface generate-typescript --framework-dir ${everest-framework_SOURCE_DIR} --output-dir ${GENERATED_INTERFACE_TS_DIR} ${INTERFACE_NAME} > /dev/null
        COMMAND
            ${CMAKE_COMMAND} -E remove -f ${EV_JS_TYPE_LAYER_DIR}/.tsc_done
        WORKING_DIRECTORY
            ${PROJECT_SOURCE_DIR}
    )

    add_custom_target(${GENERATE_INTERFACE_TARGET}
        DEPENDS
            ${GENERATED_INTERFACE_TS_DIR}/${INTERFACE_NAME}.ts
    )

    add_dependencies(ev_js_type_layer_tsc ${GENERATE_INTERFACE_TARGET})

endfunction ()


function (_ev_add_interface_target_ts INTERFACE_NAME)

    add_custom_command(
        COMMENT
            "Transpiling typescript sources for interface '${INTERFACE_NAME}'"
        OUTPUT
            ${EV_JS_TYPE_LAYER_DIST_DIR}/interface/${INTERFACE_NAME}.js
            ${EV_JS_TYPE_LAYER_DIST_DIR}/interface/${INTERFACE_NAME}.d.ts
        DEPENDS
            ev_js_type_layer_tsc
    )

    file (MAKE_DIRECTORY ${EV_JS_TYPE_LAYER_DIST_DIR}/interface)

    add_custom_command(
        COMMENT
            "Copying manifest of interface '${INTERFACE_NAME}' for evererstjs"
        OUTPUT
            ${EV_JS_TYPE_LAYER_DIST_DIR}/interface/${INTERFACE_NAME}.json
        COMMAND
            ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/${INTERFACE_NAME}.json ${EV_JS_TYPE_LAYER_DIST_DIR}/interface/
        DEPENDS
            ${INTERFACE_NAME}.json
    )

    add_custom_target(interface_${INTERFACE_NAME}_js
        DEPENDS
            ${EV_JS_TYPE_LAYER_DIST_DIR}/interface/${INTERFACE_NAME}.js
            ${EV_JS_TYPE_LAYER_DIST_DIR}/interface/${INTERFACE_NAME}.json
    )

endfunction ()


function (_ev_add_module_target_ts MODULE_NAME)

    # define target for generating typescript definitions
    set(GENERATED_MODULE_TS_DIR ${EV_JS_TYPE_LAYER_DIR}/src/module)

    add_custom_command(
        COMMENT
            "Generating typescript source files for module '${MODULE_NAME}'"
        OUTPUT
            ${GENERATED_MODULE_TS_DIR}/${MODULE_NAME}.ts
        COMMAND
            ${EV_CLI} module generate-typescript --framework-dir ${everest-framework_SOURCE_DIR} --output-dir ${GENERATED_MODULE_TS_DIR} ${MODULE_NAME} > /dev/null
        COMMAND
            ${CMAKE_COMMAND} -E remove -f ${EV_JS_TYPE_LAYER_DIR}/.tsc_done
        DEPENDS
            ${CMAKE_CURRENT_SOURCE_DIR}/${MODULE_NAME}/manifest.json
        WORKING_DIRECTORY
            ${PROJECT_SOURCE_DIR}
    )

    add_custom_target(generate_module_${MODULE_NAME}_ts
        DEPENDS
            ${GENERATED_MODULE_TS_DIR}/${MODULE_NAME}.ts
    )

    add_dependencies(ev_js_type_layer_tsc generate_module_${MODULE_NAME}_ts)

    add_custom_command(
        COMMENT
            "Transpiling typescript source files for module '${MODULE_NAME}'"
        OUTPUT
            ${EV_JS_TYPE_LAYER_DIST_DIR}/module/${MODULE_NAME}.js
            ${EV_JS_TYPE_LAYER_DIST_DIR}/module/${MODULE_NAME}.d.ts
        DEPENDS
            ev_js_type_layer_tsc
        WORKING_DIRECTORY
            ${EV_JS_TYPE_LAYER_DIR}
    )

    add_custom_command(
        COMMENT
            "Copying manifest for module '${MODULE_NAME}' to everestjs"
        OUTPUT
            ${EV_JS_TYPE_LAYER_DIST_DIR}/module/${MODULE_NAME}.json
        COMMAND
            ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/${MODULE_NAME}/manifest.json ${EV_JS_TYPE_LAYER_DIST_DIR}/module/${MODULE_NAME}.json
        DEPENDS
            ${CMAKE_CURRENT_SOURCE_DIR}/${MODULE_NAME}/manifest.json
    )

    add_custom_target(module_${MODULE_NAME}_js
        DEPENDS
            ${EV_JS_TYPE_LAYER_DIST_DIR}/module/${MODULE_NAME}.js
            ${EV_JS_TYPE_LAYER_DIST_DIR}/module/${MODULE_NAME}.json
    )

endfunction ()


function(ev_setup_js_module)
    get_filename_component(MODULE_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)

    set (JS_MODULE_PACKAGE_DIR ${EV_STAGE_MODULE_DIR}/${MODULE_NAME})

    if (${MODULE_NAME} IN_LIST EV_SYMBOLIC_LINKED_JS_MODULES OR EV_SYMBOLIC_LINKED_JS_MODULES STREQUAL "ALL")
        if (NOT IS_SYMLINK ${JS_MODULE_PACKAGE_DIR} AND IS_DIRECTORY ${JS_MODULE_PACKAGE_DIR})
            # remove if real directory
            # FIXME (aw): should these commands be checked, so we do only safe deleting?
            file(REMOVE_RECURSE ${JS_MODULE_PACKAGE_DIR})
        endif ()

        file (CREATE_LINK ${CMAKE_CURRENT_SOURCE_DIR} ${JS_MODULE_PACKAGE_DIR} SYMBOLIC)

        return ()
    endif ()

    if (IS_SYMLINK ${JS_MODULE_PACKAGE_DIR})
        file(REMOVE_RECURSE ${JS_MODULE_PACKAGE_DIR})
    endif ()

    if (NOT EXISTS ${JS_MODULE_PACKAGE_DIR})
        # in case the directory got removed, we need to invalidate our .npm* files
        file (REMOVE
            ${CMAKE_CURRENT_BINARY_DIR}/.last_rsync_ts
            ${CMAKE_CURRENT_BINARY_DIR}/.npm_install_done 
            ${CMAKE_CURRENT_BINARY_DIR}/.npm_package_done
        )
    endif ()

    file (MAKE_DIRECTORY ${JS_MODULE_PACKAGE_DIR})

    # the initial copy install should be done at the configure stage already
    # if the timestamp of the copied package.json is older than the last npm_install_done, then we want to do it by ourself
    execute_process(
        COMMAND
            rsync -ai --delete --exclude "node_modules" --exclude "CMakeLists.txt" --exclude "dist" ${CMAKE_CURRENT_SOURCE_DIR}/ ${JS_MODULE_PACKAGE_DIR}/
        OUTPUT_QUIET
    )
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -E touch ${CMAKE_CURRENT_BINARY_DIR}/.last_rsync_ts
        OUTPUT_QUIET
    )

    set (PACKAGE_JSON ${CMAKE_CURRENT_SOURCE_DIR}/package.json)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${PACKAGE_JSON})

    set (NPM_INSTALL_DONE ${CMAKE_CURRENT_BINARY_DIR}/.npm_install_done)

    # FIXME (aw): this is exactly the same cmake code as in everest-framework (code dup...)
    if ((NOT EXISTS ${NPM_INSTALL_DONE}) OR (${PACKAGE_JSON} IS_NEWER_THAN ${NPM_INSTALL_DONE}))
           # npm install --no-save $<TARGET_FILE_DIR:everestjs>/package > ${CMAKE_CURRENT_BINARY_DIR}/.npm_install_log 2>&1 || (cat ${CMAKE_CURRENT_BINARY_DIR}/.npm_install_log; false)

        message (STATUS "Installing package dependencies for javascript module ${MODULE_NAME}")
        execute_process(
            COMMAND
                npm install --no-save ${EV_JS_TYPE_LAYER_DIR}/lib
            WORKING_DIRECTORY
                ${JS_MODULE_PACKAGE_DIR}
            OUTPUT_QUIET
            RESULT_VARIABLE
                NPM_INSTALL_FAILED
        )

        if (NPM_INSTALL_FAILED)
            message (FATAL_ERROR "Installing npm dependencies for everest.js failed")
        endif ()

        execute_process(
            COMMAND
                ${CMAKE_COMMAND} -E touch ${NPM_INSTALL_DONE}
        )
    endif()

    add_custom_target(rsync_check_${MODULE_NAME}
        COMMAND
            # just make sure this directory exists
            ${CMAKE_COMMAND} -E make_directory ${JS_MODULE_PACKAGE_DIR}
        COMMAND 
            # reset parent directory timestamp, so we won't see changes
            # only due to this, which might happen because of excluded
            # directories changing
            rsync -dt --exclude="*" ${CMAKE_CURRENT_SOURCE_DIR}/ ${JS_MODULE_PACKAGE_DIR}/
        COMMAND
            rsync -ai --delete --exclude "node_modules" --exclude "CMakeLists.txt" --exclude "dist" ${CMAKE_CURRENT_SOURCE_DIR}/ ${JS_MODULE_PACKAGE_DIR}/ | grep . -q && touch ${CMAKE_CURRENT_BINARY_DIR}/.last_rsync_ts || true
    )

    add_custom_command(
        COMMENT
            "Checking for changed files in JS module '${MODULE_NAME}'"
        OUTPUT
            .last_rsync_ts
        DEPENDS
            rsync_check_${MODULE_NAME}
    )

    add_custom_command(
        COMMENT
            "Building npm package for javascript module ${MODULE_NAME}"
        OUTPUT
            .npm_package_done
        COMMAND
            npm run build --if-present > ${CMAKE_CURRENT_BINARY_DIR}/.npm_package_log 2>&1 || (cat ${CMAKE_CURRENT_BINARY_DIR}/.npm_package_log; false)
        COMMAND
            touch ${CMAKE_CURRENT_BINARY_DIR}/.npm_package_done
        DEPENDS
            .last_rsync_ts
            module_${MODULE_NAME}_js

        WORKING_DIRECTORY
            ${JS_MODULE_PACKAGE_DIR}
    )

    set (EV_PACKAGE_JS_MODULE_TARGET ev_package_${MODULE_NAME})
    add_custom_target(${EV_PACKAGE_JS_MODULE_TARGET}
        DEPENDS
            .npm_package_done
    )

    set_property(
        TARGET
            ev_setup_stage
        APPEND
        PROPERTY
            ADDITIONAL_CLEAN_FILES .npm_package_done 
    )

    add_dependencies(ev_setup_stage ${EV_PACKAGE_JS_MODULE_TARGET})

endfunction()


# wrapper function for hiding global variables
function (_ev_setup_js_type_layer)
    file (MAKE_DIRECTORY ${EV_JS_TYPE_LAYER_DIR})

    set (PACKAGE_JSON ${CMAKE_CURRENT_LIST_DIR}/package.json)
    set (TSCONFIG_JSON ${CMAKE_CURRENT_LIST_DIR}/tsconfig.json)
    set (NPM_INSTALL_DONE ${EV_JS_TYPE_LAYER_DIR}/.npm_install_done)

    # we need a reinstall if .npm_install does not exist, or if its timestamp is older than the current package.json
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${PACKAGE_JSON})

    if ((NOT EXISTS ${NPM_INSTALL_DONE}) OR (${PACKAGE_JSON} IS_NEWER_THAN ${NPM_INSTALL_DONE}))
        file (COPY ${PACKAGE_JSON} DESTINATION ${EV_JS_TYPE_LAYER_DIR})
        file (COPY ${TSCONFIG_JSON} DESTINATION ${EV_JS_TYPE_LAYER_DIR})
        message (STATUS "Installing package dependencies for everestjs type layer")
        execute_process(
            COMMAND
                npm install --no-save ${everest-framework_BINARY_DIR}/everestjs
            WORKING_DIRECTORY
                ${EV_JS_TYPE_LAYER_DIR}
            OUTPUT_QUIET
            RESULT_VARIABLE
                NPM_INSTALL_FAILED
        )

        if (NPM_INSTALL_FAILED)
            message (FATAL_ERROR "Installing npm dependencies for the everest.js type layer failed")
        endif ()

        execute_process(
            COMMAND
                ${CMAKE_COMMAND} -E touch ${NPM_INSTALL_DONE}
        )

        file (MAKE_DIRECTORY ${EV_JS_TYPE_LAYER_DIST_DIR})
        file (COPY ${PACKAGE_JSON} DESTINATION ${EV_JS_TYPE_LAYER_DIST_DIR})
    endif()

    add_custom_target(ev_js_type_layer_tsc
        DEPENDS
            everestjs_package
        BYPRODUCTS
            ${EV_JS_TYPE_LAYER_DIR}/.tsc_done
        COMMAND
            test -e ${EV_JS_TYPE_LAYER_DIR}/.tsc_done || npx tsc
        COMMAND
            ${CMAKE_COMMAND} -E touch ${EV_JS_TYPE_LAYER_DIR}/.tsc_done
        WORKING_DIRECTORY
            ${EV_JS_TYPE_LAYER_DIR}
    )

endfunction()

_ev_setup_js_type_layer()

set (EV_JS_TYPE_LAYER_MODULES "")
