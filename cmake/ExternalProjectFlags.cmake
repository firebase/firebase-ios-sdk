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

# Assemble the git-related arguments to an external project making use of the
# latest features where available but avoiding them when run under CMake
# versions that don't support them.
#
# The complete set of git-related arguments are stored as a list in the
# variable named by RESULT_VAR in the calling scope.
#
# Currently this handles:
#   * GIT_SUBMODULES -- added on CMake 3.0 or later. Earlier CMakes will
#       check out all submodules.
#   * GIT_SHALLOW -- added by default on CMake 3.6 or later. Disable by passing
#       GIT_SHALLOW OFF
#   * GIT_PROGRESS -- added by default on CMake 3.8 or later. Disable by
#       passing GIT_PROGRESS OFF
function(ExternalProject_GitSource RESULT_VAR)
  # Parse arguments
  set(options "")
  set(single_value GIT_REPOSITORY GIT_TAG GIT_PROGRESS GIT_SHALLOW)
  set(multi_value GIT_SUBMODULES)
  cmake_parse_arguments(EP "${options}" "${single_value}" "${multi_value}" ${ARGN})

  set(
    result
    GIT_REPOSITORY ${EP_GIT_REPOSITORY}
    GIT_TAG ${EP_GIT_TAG}
    ${EP_UNPARSED_ARGUMENTS}
  )

  # CMake 3.0 added support for constraining the set of submodules to clone
  if(NOT (CMAKE_VERSION VERSION_LESS "3.0") AND EP_GIT_SUBMODULES)
    list(APPEND result GIT_SUBMODULES ${EP_GIT_SUBMODULES})
  endif()

  # CMake 3.6 added support for shallow git clones. Use a shallow clone if
  # available
  if(NOT (CMAKE_VERSION VERSION_LESS "3.6"))
    if(NOT EP_GIT_SHALLOW)
      set(EP_GIT_SHALLOW ON)
    endif()

    list(APPEND result GIT_SHALLOW ${EP_GIT_SHALLOW})
  endif()

  # CMake 3.8 added support for showing progress for large downloads
  if(NOT (CMAKE_VERSION VERSION_LESS "3.8"))
    if(NOT EP_GIT_PROGRESS)
      set(EP_GIT_PROGRESS ON)
    endif()

    list(APPEND result GIT_PROGRESS ${EP_GIT_PROGRESS})
  endif()

  set(${RESULT_VAR} ${result} PARENT_SCOPE)

endfunction()
