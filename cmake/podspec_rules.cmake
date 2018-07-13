# Copyright 2018 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include(CMakeParseArguments)

# Reads properties from the given podspec and generates a cmake file that
# defines the equivalent framework.
#
# Only does anything useful on Apple platforms. On non-Apple platforms, this
# function has no effect--no target is created.
macro(podspec_framework PODSPEC_FILE)
  if(APPLE)
    set(multi SPECS)
    cmake_parse_arguments(psf "" "" "${multi}" ${ARGN})

    get_filename_component(_properties_file ${PODSPEC_FILE} NAME_WE)
    set(_properties_file ${_properties_file}.cmake)

    execute_process(
      COMMAND
        ${FIREBASE_SOURCE_DIR}/cmake/podspec_cmake.rb
        ${PODSPEC_FILE}
        ${CMAKE_CURRENT_BINARY_DIR}/${_properties_file}
        ${psf_SPECS}
    )

    # Get CMake to automatically re-run if the generation script or the podspec
    # source changes.
    configure_file(
      ${FIREBASE_SOURCE_DIR}/cmake/podspec_cmake.rb
      ${CMAKE_CURRENT_BINARY_DIR}/podspec_cmake.rb.stamp
    )

    get_filename_component(_podspec_basename ${PODSPEC_FILE} NAME)
    configure_file(
      ${PODSPEC_FILE}
      ${CMAKE_CURRENT_BINARY_DIR}/${_podspec_basename}.stamp
    )
    include(${CMAKE_CURRENT_BINARY_DIR}/${_properties_file})
  endif()
endmacro()
