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

    get_filename_component(_pod_name ${PODSPEC_FILE} NAME_WE)
    set(_properties_file ${_pod_name}.cmake)

    # Use bundler only if the current source tree has it set up. Otherwise fall
    # back on the system ruby setup, which may have CocoaPods installed.
    set(psf_runner ruby)
    if(EXISTS ${FIREBASE_SOURCE_DIR}/.bundle)
      set(psf_runner bundle exec)
    endif()

    execute_process(
      COMMAND
        ${psf_runner}
        ${FIREBASE_SOURCE_DIR}/cmake/podspec_cmake.rb
        ${PODSPEC_FILE}
        ${CMAKE_CURRENT_BINARY_DIR}/${_properties_file}
        ${psf_SPECS}
    )

    # Get CMake to automatically re-run if the generation script or the podspec
    # source changes.
    set_property(
      DIRECTORY APPEND PROPERTY
      CMAKE_CONFIGURE_DEPENDS ${FIREBASE_SOURCE_DIR}/cmake/podspec_cmake.rb
    )
    set_property(
      DIRECTORY APPEND PROPERTY
      CMAKE_CONFIGURE_DEPENDS ${PODSPEC_FILE}
    )

    include(${CMAKE_CURRENT_BINARY_DIR}/${_properties_file})

    # Non-Firestore Objective-C code in this repository is not as strict about
    # warnings.
    target_compile_options(
      ${_pod_name}
      PRIVATE
      -Wno-unused-parameter
      -Wno-deprecated-declarations
    )
  endif()
endmacro()
