# Copyright 2017 Google
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
include(ExternalProject)

# Builds an existing Xcode project or workspace as an external project in CMake.
#
# xcodebuild(<framework> [<option>...])
#
# Options:
# ``DEPENDS <projects>...``
#   Targets on which the project depends
# ``SCHEME <scheme>``
#   The scheme to build in the workspace, defaults to <framework>-<platform>,
#   where <platform> is always "macOS".
# ``WORKSPACE <workspace>``
#   Location of the xcworkspace file containing the target to build. Defaults to
#   Example/Firebase.xcworkspace.
function(xcodebuild framework)
  # Parse arguments
  set(options "")
  set(single_value SCHEME WORKSPACE)
  set(multi_value DEPENDS)
  cmake_parse_arguments(xcb "${options}" "${single_value}" "${multi_value}" ${ARGN})

  if(NOT xcb_WORKSPACE)
    set(xcb_WORKSPACE ${PROJECT_SOURCE_DIR}/Example/Firebase.xcworkspace)
  endif()

  # TODO(mcg): Investigate supporting non-macOS platforms
  # The canonical way to build and test for iOS is via Xcode and CocoaPods so
  # it's not super important to make this work here
  set(platform macOS)
  set(destination "platform=macOS,arch=x86_64")
  set(scheme "${framework}-${platform}")

  # CMake has a variety of release types, but Xcode has just one by default.
  if(CMAKE_BUILD_TYPE STREQUAL Debug)
    set(configuration Debug)
  else()
    set(configuration Release)
  endif()

  # Pipe build output through xcpretty if it's available
  find_program(xcpretty_cmd xcpretty)
  if(xcpretty_cmd)
    set(pipe_xcpretty "|" ${xcpretty_cmd})
  endif()

  ExternalProject_Add(
    ${framework}
    DEPENDS ${xcb_DEPENDS}

    PREFIX ${PROJECT_BINARY_DIR}

    # The source directory doesn't actually matter
    SOURCE_DIR ${PROJECT_SOURCE_DIR}
    INSTALL_DIR ${FIREBASE_INSTALL_DIR}/Frameworks

    CONFIGURE_COMMAND ""

    BUILD_COMMAND
      xcodebuild
        -workspace ${xcb_WORKSPACE}
        -scheme ${scheme}
        -configuration ${configuration}
        -destination ${destination}
        CONFIGURATION_BUILD_DIR=<INSTALL_DIR>
        build
        ${pipe_xcpretty}
    BUILD_ALWAYS ${BUILD_PODS}

    INSTALL_COMMAND ""
    TEST_COMMAND ""
  )

endfunction()
