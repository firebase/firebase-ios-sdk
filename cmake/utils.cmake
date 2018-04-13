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

# Defines a new test executable and does all the things we want done with
# tests:
#
#   * add_executable (with the given arguments)
#   * add_Test - defines a test with the same name
#   * declares that the test links against gtest
#   * adds the executable as a dependency of the `check` target.
function(cc_test name)
  add_executable(${name} ${ARGN})
  add_test(${name} ${name})

  target_link_libraries(${name} GTest::GTest GTest::Main)
endfunction()
