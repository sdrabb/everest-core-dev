set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")

list(APPEND EVEREST_MODULES_LIST
    # Charger
    # EnergyManager
    # EnergyNode
    # EvseManager
    # EvseSlac
    Example
    ExampleUser
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
    Store
    # SunspecReader
    # SunspecScanner
    # YetiDriver
    # TestPwr
)

set(EVEREST_MODULES "")
foreach(ENTRY ${EVEREST_MODULES_LIST})
    if(IS_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/${ENTRY})
        if(NOT "${ENTRY}" STREQUAL "CMakeFiles")
            list(APPEND EVEREST_MODULES ${ENTRY})
        endif()
    endif()
endforeach()

# set(FORCE_UPDATE_COMMANDS "")
# foreach(EVEREST_MODULE ${EVEREST_MODULES})
#     if(NOT ${EVEREST_MODULE} MATCHES "^Js")
#         list(APPEND FORCE_UPDATE_COMMANDS
#             COMMAND ${EV_CLI} module update --framework-dir ${everest-framework_SOURCE_DIR} -f ${EVEREST_MODULE}
#         )
#     endif()
# endforeach()

# add_custom_target(force_update_all_modules
#     ${FORCE_UPDATE_COMMANDS}
#     WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
# )

message("everest modules: ${EVEREST_MODULES}")
foreach(EVEREST_MODULE ${EVEREST_MODULES})
    add_subdirectory(${EVEREST_MODULE})
endforeach()
