# Minimum required CMake version
cmake_minimum_required(VERSION 2.8.12 FATAL_ERROR)

# MIRTK
find_package(MIRTK REQUIRED)
include_directories(${MIRTK_INCLUDE_DIRS})
link_directories(${MIRTK_LIBRARY_DIRS})
# find MIRTK libraries
foreach (mirtklib IN ITEMS ${MIRTK_MODULES_ENABLED})
  string(COMPARE NOTEQUAL "${mirtklib}" "Applications" mirtklibkeep)
  if (${mirtklibkeep})
    set(MIRTK_LIBRARIES "${MIRTK_LIBRARIES} -lMIRTK${mirtklib}")
  endif()
endforeach ()
string(STRIP ${MIRTK_LIBRARIES} MIRTK_LIBRARIES)
MESSAGE( STATUS "MIRTK_LIBRARIES:         " ${MIRTK_LIBRARIES} )

# VTK
find_package(VTK REQUIRED)
include(${VTK_USE_FILE})
link_directories(Test ${VTK_LIBRARIES})

# FLAGS
if(UNIX)
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -std=gnu++0x")
endif()

# set make output directories
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

macro(add_dhcp_executable name)
  add_executable(${name} ${name}.cc ${ARGN})
  target_link_libraries(${name} ${MIRTK_LIBRARIES})
  target_link_libraries(${name} ${VTK_LIBRARIES})
endmacro()

SUBDIRS(applications)
