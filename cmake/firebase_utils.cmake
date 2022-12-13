# Copyright 2022 Google LLC
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

# Join all the input arguments together using the <glue> string and store the
# result in the named <output_variable>.
#
# TODO: Delete this function once cmake_minimum_required() is 3.12 or greater,
# in which case the built-in list(JOIN ...) command should be used instead.
# See https://cmake.org/cmake/help/v3.12/command/string.html#join
function(firebase_string_join glue output_variable)
  list(LENGTH ARGN ARGN_LENGTH)

  if(ARGN_LENGTH EQUAL 0)
    set("${output_variable}" "" PARENT_SCOPE)
    return()
  endif()

  list(GET ARGN 0 result_string)
  list(REMOVE_AT ARGN 0)

  foreach(argv_element ${ARGN})
    string(APPEND result_string "${glue}")
    string(APPEND result_string "${argv_element}")
  endforeach()

  set("${output_variable}" "${result_string}" PARENT_SCOPE)
endfunction(firebase_string_join)

# A wrapper around the built-in execute_process() function that adds some
# additional functionality.
#
# In addition to calling the built-in execute_process() function, this function
# also does the following:
# 1. Logs the arguments of the process being executed.
# 2. Fails if the process completes with a non-zero exit code.
function(firebase_execute_process)
  cmake_parse_arguments(
    "ARG" # prefix
    "" # options
    "WORKING_DIRECTORY" # one_value_keywords
    "COMMAND" # multi_value_keywords
    ${ARGN}
  )

  list(LENGTH ARG_COMMAND ARG_COMMAND_LENGTH)
  if(ARG_COMMAND_LENGTH EQUAL 0)
    message(
      FATAL_ERROR
      "firebase_execute_process() COMMAND must be given at least one value."
    )
  endif()

  set(execute_process_args "")
  list(APPEND execute_process_args "COMMAND" ${ARG_COMMAND})

  if("${ARG_WORKING_DIRECTORY}" STREQUAL "")
    set(LOG_SUFFIX "")
  else()
    set(LOG_SUFFIX " (working directory: ${ARG_WORKING_DIRECTORY})")
    list(APPEND execute_process_args "WORKING_DIRECTORY" "${ARG_WORKING_DIRECTORY}")
  endif()

  firebase_string_join(" " ARG_COMMAND_STR ${ARG_COMMAND})
  message(
    STATUS
    "firebase_execute_process(): "
    "running command: ${ARG_COMMAND_STR}${LOG_SUFFIX}"
  )

  execute_process(
    ${execute_process_args}
    RESULT_VARIABLE process_exit_code
  )

  if(NOT process_exit_code EQUAL 0)
    message(
      FATAL_ERROR
      "firebase_execute_process(): command failed with non-zero exit code "
      "${process_exit_code}: ${ARG_COMMAND_STR}${LOG_SUFFIX}"
    )
  endif()

endfunction(firebase_execute_process)
