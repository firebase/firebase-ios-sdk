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

if(LIBFUZZER_FOUND)
  if (NOT TARGET LibFuzzer)
    add_library(LibFuzzer STATIC IMPORTED)
    set_target_properties(
      LibFuzzer PROPERTIES
      IMPORTED_LOCATION ${LIBFUZZER_LIBRARY}
    )
  endif()
endif(LIBFUZZER_FOUND)
