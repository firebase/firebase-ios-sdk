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

# Automatically looks for lib{LIBRARY_NAME}.a, therefore we search for "Fuzzer"
# in the directory in which we have the libFuzzer.a file.
message(WARNING "@@@@ FindLibFuzzer.cmake")
if(OSS_FUZZ)
  message(WARNING "@@@@  OSS_FUZZING_ENGINE = ${OSS_FUZZING_ENGINE}")
  message(WARNING "@@@@  LIB_FUZZING_ENGINE = ${LIB_FUZZING_ENGINE}")
  if(NOT TARGET LibFuzzer)
    message(WARNING "@@@@ Importing location = ${OSS_FUZZING_ENGINE}")
    add_library(LibFuzzer STATIC IMPORTED)
    set_target_properties(
      LibFuzzer PROPERTIES
      IMPORTED_LOCATION ${OSS_FUZZING_ENGINE}
    )
  endif()
else() # Look for libFuzzer.a that was manually built.
  message(WARNING "@@@@ Looking for libFuzzer.a that was manually built")
  find_library(
    LIBFUZZER_LIBRARY
    NAMES Fuzzer
    HINTS
      ${FIREBASE_BINARY_DIR}/src/libfuzzer
  )

  include(FindPackageHandleStandardArgs)
  find_package_handle_standard_args(
    libfuzzer
    DEFAULT_MSG
    LIBFUZZER_LIBRARY
  )
  message(WARNING "@@@@ LibFuzzer found? = 4{LIBFUZZER_FOUND}")
  if(LIBFUZZER_FOUND)
    if (NOT TARGET LibFuzzer)
      add_library(LibFuzzer STATIC IMPORTED)
      set_target_properties(
        LibFuzzer PROPERTIES
        IMPORTED_LOCATION ${LIBFUZZER_LIBRARY}
      )
    endif()
  else()
    message(FATAL_ERROR "@@@@ LibFuzzer could not be found")
  endif(LIBFUZZER_FOUND)
endif()
