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

# OSS_FUZZ provides its own fuzzing library in LIB_FUZZING_ENGINE environment
# variable that we pass to Firestore cmake environment as OSS_FUZZING_ENGINE.
# For local fuzzing, search for the libFuzzer.a library that was manually built.
if(OSS_FUZZ)
  set(FUZZING_LIBRARY_LOCATION ${OSS_FUZZING_ENGINE})
else()
  find_library(
    FUZZING_LIBRARY_LOCATION
    NAMES Fuzzer
    HINTS ${FIREBASE_BINARY_DIR}/external/src/libfuzzer
  )
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  FUZZING_LIBRARY
  DEFAULT_MSG
  FUZZING_LIBRARY_LOCATION
)

if(FUZZING_LIBRARY_FOUND)
  if (NOT TARGET FuzzingLibrary)
    add_library(FuzzingLibrary STATIC IMPORTED)
    set_target_properties(
      FuzzingLibrary PROPERTIES
      IMPORTED_LOCATION ${FUZZING_LIBRARY_LOCATION}
    )
  endif()
else()
  message(FATAL_ERROR "Could not find the fuzzing library.")
endif(FUZZING_LIBRARY_FOUND)
