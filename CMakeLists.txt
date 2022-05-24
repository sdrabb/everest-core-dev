cmake_minimum_required(VERSION 3.15)

project(EVerest VERSION 0.1
                DESCRIPTION "The open operating system for e-mobility charging stations"
		LANGUAGES CXX C)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
endif()

option(EVEREST_CROSS_COMPILE "Cross compile the EVerest framework" OFF)
if(EVEREST_CROSS_COMPILE)
    if(NOT BOOST_ROOT)
        message(FATAL_ERROR "Please set BOOST_ROOT to a cross compiled version of Boost!")
    endif()
    set(Boost_USE_STATIC_LIBS ON)
    set(CMAKE_SYSTEM_NAME Linux)
    set(CMAKE_SYSTEM_PROCESSOR arm)
    set(BOOST_LOG_DYN_LINK OFF)
    set(BOOST_ALL_DYN_LINK OFF)
else()
    add_definitions(-DBOOST_LOG_DYN_LINK)
endif()

#add_definitions(-DEVEREST_SRC_DIR=${PROJECT_SOURCE_DIR})

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/dist" CACHE PATH "..." FORCE)
endif()

option(CREATE_SYMLINKS "Create symlinks to javascript modules and auxillary files - for development purposes" OFF)

option(BUILD_TESTING "Run unit tests" OFF)

# configure clang-tidy if requested
option(CMAKE_RUN_CLANG_TIDY "Run clang-tidy" OFF)
if(CMAKE_RUN_CLANG_TIDY)
    message("Enabling clang-tidy")
    set(CMAKE_CXX_CLANG_TIDY clang-tidy)
endif()

# # build doxygen documentation if doxygen is available
# find_package(Doxygen)
# if(DOXYGEN_FOUND)
#     set( DOXYGEN_OUTPUT_DIRECTORY dist/docs )
#     doxygen_add_docs(doxygen everest.js include lib src)
# else()
#     message("Doxygen is needed to generate documentation")
# endif()

list(APPEND CMAKE_MODULE_PATH ${CMAKE_BINARY_DIR})
list(APPEND CMAKE_PREFIX_PATH ${CMAKE_BINARY_DIR})
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

find_package(EDM REQUIRED)

set (EV_STAGE_DIR ${CMAKE_BINARY_DIR}/ev-stage)
set (EV_MODULE_STAGE_DIR ${EV_STAGE_DIR}/modules)
set (EV_SYMBOLIC_LINKED_JS_MODULES "")
set (EV_GENERATED_OUTPUT_DIR ${CMAKE_BINARY_DIR}/generated)

file (MAKE_DIRECTORY ${EV_MODULE_STAGE_DIR})
add_custom_target(ev_setup_stage ALL
    COMMAND
        ${CMAKE_COMMAND} -E create_symlink $<TARGET_FILE:manager>  $<TARGET_FILE_NAME:manager>
    WORKING_DIRECTORY
        ${EV_STAGE_DIR}
)

include(EvCli)

find_package(Boost COMPONENTS filesystem program_options system thread REQUIRED)

# testing
include(CTest)
if(BUILD_TESTING)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)

    include(CodeCoverage)

    append_coverage_compiler_flags()

    add_subdirectory(tests)

    setup_target_for_coverage_gcovr_html(
        NAME gcovr_coverage
        EXECUTABLE test_config
        DEPENDENCIES test_config everest
    )

    setup_target_for_coverage_lcov(
        NAME lcov_coverage
        EXECUTABLE test_config
        DEPENDENCIES test_config everest
    )
else()
    message("Not running unit tests")
endif()

# clean this directory when make clean
set_property(
    DIRECTORY
    PROPERTY ADDITIONAL_CLEAN_FILES
        ${GENERATED_OUTPUT_DIR}
)

# interfaces
add_subdirectory(interfaces)

# modules
add_subdirectory(modules)


install(DIRECTORY "interfaces/" DESTINATION interfaces
        FILES_MATCHING PATTERN "*.json"
)
