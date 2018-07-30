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

if(TARGET LibFuzzer)
  return()
endif()

# OSS_FUZZ provides its own fuzzing library in LIB_FUZZING_ENGINE environment
# variable that we pass to Firestore cmake environment as OSS_FUZZING_ENGINE.
# For local fuzzing, search for the libFuzzer.a that was manually built.
if(OSS_FUZZ)
  set(FUZZING_LIBRARY_LOCATION ${OSS_FUZZING_ENGINE})
else()
  # Search for libFuzzer.a in the downloaded source directory.
  set(LIBFUZZER_SOURCE_LOCATION ${FIREBASE_BINARY_DIR}/external/src/libfuzzer)

  find_library(
    FUZZING_LIBRARY_LOCATION
    NAMES Fuzzer
    HINTS ${LIBFUZZER_SOURCE_LOCATION}
  )

  include(FindPackageHandleStandardArgs)
  find_package_handle_standard_args(
    LIBFUZZER
    DEFAULT_MSG
    FUZZING_LIBRARY_LOCATION
  )

  if(NOT LIBFUZZER_FOUND)
    message(FATAL_ERROR "Could not find LibFuzzer in location: "
            "'${LIBFUZZER_SOURCE_LOCATION}'")
  endif()
endif(OSS_FUZZ)

add_library(LibFuzzer STATIC IMPORTED)
set_target_properties(
  LibFuzzer PROPERTIES
  IMPORTED_LOCATION ${FUZZING_LIBRARY_LOCATION}
)
