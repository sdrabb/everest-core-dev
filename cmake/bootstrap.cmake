if (NOT NO_FETCH_CONTENT)
    include(FetchContent)
endif ()

#
# get everest-cmake
# this needs to be done in current scope, because everest-cmake is designed that way
#
set (EVEREST_CMAKE_SEARCH_PATH "")
if (NOT everest-cmake_DIR AND NOT NO_FETCH_CONTENT)
    # everest-cmake has not been found and we're allowed to fetch
    message(STATUS "Retreiving everest-cmake using FetchContent")
    FetchContent_Declare(
        everest-cmake
        GIT_REPOSITORY https://github.com/EVerest/everest-cmake.git
        GIT_TAG        feature/python_venv
    )
    FetchContent_Populate(everest-cmake)
    list(APPEND EVEREST_CMAKE_SEARCH_PATH PATHS "${everest-cmake_SOURCE_DIR}")
endif ()

find_package(
    everest-cmake 0.2
    COMPONENTS bundling
    ${EVEREST_CMAKE_SEARCH_PATH}
    REQUIRED
)

unset (EVEREST_CMAKE_SEARCH_PATH) # clean up

#
# look out for ev-cli
#
if (NOT EV_CLI)
    if (NO_FETCH_CONTENT)
        message(FATAL_ERROR "Cannot fetch ev-cli due to NO_FETCH_CONTENT=1, please specify EV_CLI manually")
    endif ()

    # make sure python3 venv is available
    evc_assert_python_venv()

    message(STATUS "Retrieving ev-cli using FetchContent")
    # FIXME (aw): this will be removed if ev-cli gets into this repository

    FetchContent_Declare(
        everest-utils
        GIT_REPOSITORY https://github.com/EVerest/everest-utils
        GIT_TAG        main
    )
    FetchContent_Populate(everest-utils)

    execute_process(
        COMMAND ${PYTHON3_VENV_EXECUTABLE} -m pip install ${everest-utils_SOURCE_DIR}/ev-dev-tools
    )

    find_program (EV_CLI ev-cli
        PATHS "${PYTHON3_VENV_DIR}/bin"
        NO_SYSTEM_ENVIRONMENT_PATH
        REQUIRED
    )
endif ()

include(config-run-script)
include(config-run-nodered-script)
