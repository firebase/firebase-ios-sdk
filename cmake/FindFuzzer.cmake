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

if(TARGET Fuzzer)
  return()
endif()

# OSS Fuzz provides its own fuzzing library libFuzzingEngine.a in the path
# defined by LIB_FUZZING_ENGINE environment variable. For local fuzzing, search
# for the libFuzzer.a library that was manually built.
find_library(
  FUZZER_LOCATION
  NAMES FuzzingEngine Fuzzer
  HINTS
    $ENV{LIB_FUZZING_ENGINE}
    ${FIREBASE_BINARY_DIR}/external/src/libfuzzer
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  FUZZER
  DEFAULT_MSG
  FUZZER_LOCATION
)

if(FUZZER_FOUND)
  add_library(Fuzzer STATIC IMPORTED)
  set_target_properties(
    Fuzzer PROPERTIES
    IMPORTED_LOCATION ${FUZZER_LOCATION}
  )
endif(FUZZER_FOUND)
