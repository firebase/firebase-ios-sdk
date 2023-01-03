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

include("${CMAKE_CURRENT_LIST_DIR}/firebase_utils.cmake")

# Sets up an isolated Python interpreter, installing required dependencies.
#
# This function does the following:
# 1. Finds a Python interpreter using the best-available built-in cmake
#      mechanism do do so. This is referred to as the "host" interpreter.
# 2. Creates a Python virtualenv in the cmake binary directory using the
#      host Python interpreter found in the previous step.
# 3. Locates the Python interpreter in the virtualenv and sets its path in
#      the specified OUTVAR variable.
# 4. Runs `pip install` to install the specified required dependencies, if any,
#      in the virtualenv.
#
# This function also writes "stamp files" into the virtualenv. These files
# are used to determine if the virtualenv is up-to-date from a previous cmake
# run or if it needs to be recreated from scratch. It will simply be re-used if
# possible.
#
# If any errors occur (e.g. cannot install one of the given requirements) then a
# fatal error is logged, causing the cmake processing to terminate.
#
# See https://docs.python.org/3/library/venv.html for details about virtualenv.
#
# Arguments:
#   OUTVAR - The name of the variable into which to store the path of the
#     Python executable from the virtualenv.
#   KEY - A unique key to ensure isolation from other Python virtualenv
#     environments created by this function. This value will be incorporated
#     into the path of the virtualenv and incorporated into the name of the
#     cmake cache variable that stores its path.
#   REQUIREMENTS - (Optional) A list of Python packages to install in the
#     virtualenv. These will be given as arguments to `pip install`.
#
# Example:
#   include(python_setup)
#   FirebaseSetupPythonInterpreter(
#     OUTVAR MY_PYTHON_EXECUTABLE
#     KEY ScanStuff
#     REQUIREMENTS six absl-py
#   )
#   execute_process(COMMAND "${MY_PYTHON_EXECUTABLE}" scan_stuff.py)
function(FirebaseSetupPythonInterpreter)
  cmake_parse_arguments(
    PARSE_ARGV 0
    ARG
    "" # zero-value arguments
    "OUTVAR;KEY" # single-value arguments
    "REQUIREMENTS" # multi-value arguments
  )

  # Validate this function's arguments.
  if("${ARG_OUTVAR}" STREQUAL "")
    message(FATAL_ERROR "OUTVAR must be specified to ${CMAKE_CURRENT_FUNCTION}")
  elseif("${ARG_KEY}" STREQUAL "")
    message(FATAL_ERROR "KEY must be specified to ${CMAKE_CURRENT_FUNCTION}")
  endif()

  # Calculate the name of the cmake *cache* variable into which to store the
  # path of the Python interpreter from the virtualenv.
  set(CACHEVAR "FIREBASE_PYTHON_EXECUTABLE_${ARG_KEY}")

  set(LOG_PREFIX "${CMAKE_CURRENT_FUNCTION}(${ARG_KEY})")

  # Find a "host" Python interpreter using the best available mechanism.
  if(${CMAKE_VERSION} VERSION_LESS "3.12")
    include(FindPythonInterp)
    set(DEFAULT_PYTHON_HOST_EXECUTABLE "${PYTHON_EXECUTABLE}")
  else()
    find_package(Python3 COMPONENTS Interpreter REQUIRED)
    set(DEFAULT_PYTHON_HOST_EXECUTABLE "${Python3_EXECUTABLE}")
  endif()

  # Get the host Python interpreter on the host system to use.
  set(
    FIREBASE_PYTHON_HOST_EXECUTABLE
    "${DEFAULT_PYTHON_HOST_EXECUTABLE}"
    CACHE FILEPATH
    "The Python interpreter on the host system to use"
  )

  # Check if the virtualenv is already up-to-date by examining the contents of
  # its stamp files. The stamp files store the path of the host Python
  # interpreter and the dependencies that were installed by pip. If both of
  # these files exist and contain the same Python interpreter and dependencies
  # then just re-use the virtualenv; otherwise, re-create it.
  set(PYVENV_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/pyvenv/${ARG_KEY}")
  set(STAMP_FILE1 "${PYVENV_DIRECTORY}/cmake_firebase_python_stamp1.txt")
  set(STAMP_FILE2 "${PYVENV_DIRECTORY}/cmake_firebase_python_stamp2.txt")

  if(EXISTS "${STAMP_FILE1}" AND EXISTS "${STAMP_FILE2}")
    file(READ "${STAMP_FILE1}" STAMP_FILE1_CONTENTS)
    file(READ "${STAMP_FILE2}" STAMP_FILE2_CONTENTS)
    if(
      ("${STAMP_FILE1_CONTENTS}" STREQUAL "${FIREBASE_PYTHON_HOST_EXECUTABLE}")
      AND
      ("${STAMP_FILE2_CONTENTS}" STREQUAL "${ARG_REQUIREMENTS}")
    )
      set("${ARG_OUTVAR}" "$CACHE{${CACHEVAR}}" PARENT_SCOPE)
      message(STATUS "${LOG_PREFIX}: Using Python interpreter: $CACHE{${CACHEVAR}}")
      return()
    endif()
  endif()

  # Create the virtualenv.
  message(STATUS
    "${LOG_PREFIX}: Creating Python virtualenv in ${PYVENV_DIRECTORY} "
    "using ${FIREBASE_PYTHON_HOST_EXECUTABLE}"
  )
  file(REMOVE_RECURSE "${PYVENV_DIRECTORY}")
  firebase_execute_process(
    COMMAND
      "${FIREBASE_PYTHON_HOST_EXECUTABLE}"
      -m
      venv
      "${PYVENV_DIRECTORY}"
  )

  # Find the Python interpreter in the virtualenv.
  find_program(
    "${CACHEVAR}"
    DOC "The Python interpreter to use for ${ARG_KEY}"
    NAMES python3 python
    PATHS "${PYVENV_DIRECTORY}"
    PATH_SUFFIXES bin Scripts
    NO_DEFAULT_PATH
  )
  if(NOT ${CACHEVAR})
    message(FATAL_ERROR "Unable to find Python executable in ${PYVENV_DIRECTORY}")
  else()
    set(PYTHON_EXECUTABLE "$CACHE{${CACHEVAR}}")
    message(STATUS "${LOG_PREFIX}: Found Python executable in virtualenv: ${PYTHON_EXECUTABLE}")
  endif()

  # Install the dependencies in the virtualenv, if any are requested.
  if(NOT ("${ARG_REQUIREMENTS}" STREQUAL ""))
    message(STATUS
      "${LOG_PREFIX}: Installing Python dependencies into "
      "${PYVENV_DIRECTORY}: ${ARG_REQUIREMENTS}"
    )
    firebase_execute_process(
      COMMAND
        "${PYTHON_EXECUTABLE}"
        -m
        pip
        install
        ${ARG_REQUIREMENTS}
    )
  endif()

  # Write the stamp files.
  file(WRITE "${STAMP_FILE1}" "${FIREBASE_PYTHON_HOST_EXECUTABLE}")
  file(WRITE "${STAMP_FILE2}" "${ARG_REQUIREMENTS}")

  set("${ARG_OUTVAR}" "${PYTHON_EXECUTABLE}" PARENT_SCOPE)
endfunction(FirebaseSetupPythonInterpreter)
