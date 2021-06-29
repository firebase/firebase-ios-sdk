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

macro(podspec_version VARIABLE PODSPEC_FILE)
  execute_process(
    COMMAND
    sed -n
    -f ${PROJECT_SOURCE_DIR}/cmake/podspec_version.sed
    ${PODSPEC_FILE}
    OUTPUT_VARIABLE ${VARIABLE}
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(${VARIABLE} STREQUAL "")
    message(
      FATAL_ERROR
      "Running the sed script ${PROJECT_SOURCE_DIR}/cmake/podspec_version.sed \
      on file ${PODSPEC_FILE} failed; ensure that the `sed` executable is \
      installed and that its directory is present in the PATH environment \
      variable."
    )
  endif()
endmacro()

macro(firebase_version VARIABLE PODSPEC_FILE)
  execute_process(
    COMMAND
      sed -n
        -f ${PROJECT_SOURCE_DIR}/cmake/firebase_version.sed
        ${PODSPEC_FILE}
    OUTPUT_VARIABLE ${VARIABLE}
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(${VARIABLE} STREQUAL "")
    message(
      FATAL_ERROR
      "Running the sed script ${PROJECT_SOURCE_DIR}/cmake/firebase_version.sed \
      on file ${PODSPEC_FILE} failed; ensure that the `sed` executable is \
      installed and that its directory is present in the PATH environment \
      variable."
    )
  endif()
endmacro()

function(podspec_prep_headers FRAMEWORK_NAME)
  file(MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/Headers/${FRAMEWORK_NAME})
  execute_process(
    COMMAND
      ln -sf ${ARGN} ${PROJECT_BINARY_DIR}/Headers/${FRAMEWORK_NAME}
  )
endfunction()
