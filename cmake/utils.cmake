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

# cc_library(
#   target
#   SOURCES sources...
#   DEPENDS libraries...
# )
#
# Defines a new library target with the given target name, sources, and dependencies.
function(cc_library name)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(ccl "" "" "${multi}" ${ARGN})

  add_library(
    ${name}
    ${ccl_SOURCES}
  )
  target_link_libraries(
    ${name}
    PUBLIC
    ${ccl_DEPENDS}
  )

endfunction()

# cc_test(
#   target
#   SOURCES sources...
#   DEPENDS libraries...
# )
#
# Defines a new test executable target with the given target name, sources, and
# dependencies.  Implicitly adds DEPENDS on GTest::GTest and GTest::Main.
function(cc_test name)
  set(multi DEPENDS SOURCES)
  cmake_parse_arguments(cct "" "" "${multi}" ${ARGN})

  list(APPEND cct_DEPENDS GTest::GTest GTest::Main)

  add_executable(${name} ${cct_SOURCES})
  add_test(${name} ${name})

  target_link_libraries(${name} ${cct_DEPENDS})
endfunction()
