set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")

list(APPEND EVEREST_MODULES_LIST
    # Charger
    # EnergyManager
    # EnergyNode
    EvseManager
    # EvseSlac
    # Example
    # ExampleUser
    # JsAuth
    # JsCarSimulator
    # JsDummyTokenProvider
    # JsDummyTokenValidator
    # JsForecastDotSolar
    # JsPN532TokenProvider
    # JsRiseV2G
    # JsTibber
    # JsYetiSimulator
    # ModbusMeter
    # OCPP
    # PersistentStore
    # Store
    # SunspecReader
    # SunspecScanner
    # YetiDriver
)

set(EVEREST_MODULES "")
foreach(ENTRY ${EVEREST_MODULES_LIST})
    if(IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${ENTRY})
        if(NOT "${ENTRY}" STREQUAL "CMakeFiles")
            list(APPEND EVEREST_MODULES ${ENTRY})
        endif()
    endif()
endforeach()

set(GENERATED_MODULE_DIR ${GENERATED_OUTPUT_DIR}/src/module)

set(FORCE_UPDATE_COMMANDS "")
foreach(EVEREST_MODULE ${EVEREST_MODULES})
    if(NOT ${EVEREST_MODULE} MATCHES "^Js")
        list(APPEND FORCE_UPDATE_COMMANDS
            COMMAND ${EV_CLI} module update --framework-dir ${everest-framework_SOURCE_DIR} -f ${EVEREST_MODULE}
        )
    endif()
endforeach()

add_custom_target(force_update_all_modules
    ${FORCE_UPDATE_COMMANDS}
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
)

function(cpp_module_setup)
    get_filename_component(MODULE_NAME ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    set(MODULE_TARGET module_${MODULE_NAME})
    set(MODULE_LOADER_DIR ${GENERATED_MODULE_DIR}/${MODULE_NAME})

    add_executable(${MODULE_TARGET})

    set(MODULE_CMAKE_DIRECTIVES ${MODULE_LOADER_DIR}/mod_deps.cmake)
    if ((NOT EXISTS ${MODULE_CMAKE_DIRECTIVES}) OR (manifest.json IS_NEWER_THAN ${MODULE_CMAKE_DIRECTIVES}))
        execute_process(
            COMMAND
                ${EV_CLI} module generate-sources --framework-dir ${everest-framework_SOURCE_DIR} --output-dir ${GENERATED_OUTPUT_DIR} ${MODULE_NAME}
            WORKING_DIRECTORY
                ${PROJECT_SOURCE_DIR}
        )
    endif()

    # this populates ${MODULE_REQUIREMENTS} and ${MODULE_IMPLEMENTATIONS}
    include(${MODULE_CMAKE_DIRECTIVES})

    foreach(REQUIREMENT ${MODULE_REQUIREMENTS})
        target_link_libraries(${MODULE_TARGET}
            PRIVATE
                interface_${REQUIREMENT}_req
        )    
    endforeach()

    foreach(IMPLEMENTATION ${MODULE_IMPLEMENTATIONS})
        target_link_libraries(${MODULE_TARGET}
            PRIVATE
                interface_${IMPLEMENTATION}_impl
        )
    endforeach()
    

    set_property(
        DIRECTORY
        APPEND PROPERTY
        CMAKE_CONFIGURE_DEPENDS
            manifest.json
    )

    target_include_directories(${MODULE_TARGET} PRIVATE ${GENERATED_OUTPUT_DIR}/include)
    target_sources(${MODULE_TARGET} PRIVATE ${MODULE_LOADER_DIR}/ld-ev.cpp)
    target_compile_features(${MODULE_TARGET} PRIVATE cxx_std_14)
    target_link_libraries(${MODULE_TARGET}
        PRIVATE
            everest ${CMAKE_DL_LIBS}
            everest::log
    )

    set(MODULE_TARGET ${MODULE_TARGET} PARENT_SCOPE)
endfunction()

message("everest modules: ${EVEREST_MODULES}")
foreach(EVEREST_MODULE ${EVEREST_MODULES})
    add_subdirectory(${EVEREST_MODULE})
endforeach()
