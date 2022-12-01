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
    # make sure python3 venv is available
    evc_assert_python_venv()

    message(STATUS "Installing ev-dev-tools to python venv")
    execute_process(
        COMMAND ${PYTHON3_VENV_EXECUTABLE} -m pip install ${PROJECT_SOURCE_DIR}/tools/ev-dev-tools
    )

    find_program (EV_CLI ev-cli
        PATHS "${PYTHON3_VENV_DIR}/bin"
        NO_SYSTEM_ENVIRONMENT_PATH
        REQUIRED
    )
endif ()

include(config-run-script)
include(config-run-nodered-script)
