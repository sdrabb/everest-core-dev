set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--no-undefined")

list(APPEND EVEREST_MODULES
    # Charger
    # EnergyManager
    # EnergyNode
    # EvseManager
    # EvseSlac
    # Example
    ExampleUser
    # JsAuth
    # JsCarSimulator
    # JsDummyTokenProvider
    # JsDummyTokenValidator
    # JsForecastDotSolar
    JsExample
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

foreach(EVEREST_MODULE ${EVEREST_MODULES})
    if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${EVEREST_MODULE}/manifest.json)
        ev_register_module(${EVEREST_MODULE})
    endif()
    add_subdirectory(${EVEREST_MODULE})
endforeach()
