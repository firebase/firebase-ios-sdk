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

# Adds fuzzing options to the current build.
option(FUZZING "Build with Fuzz Testing flags" OFF)
option(OSS_FUZZ "Build for OSS Fuzz Environment" OFF)
option(OSS_FUZZING_ENGINE STRING "Fuzzing engine provided by OSS Fuzz")
#option(OSS_FLAGS "" STRING "Flags provided by OSS Fuzz Environment")

if(FUZZING)
  # If fuzzing is enabled, multiple compile and linking flags must be set.
  # These flags are set according to the compiler kind.

  # Fuzzing must be accompanied by WITH_ASAN=ON.
  if(NOT WITH_ASAN)
    message(FATAL_ERROR "Fuzzing requires WITH_ASAN=ON.")
  endif()

  if(OSS_FUZZ)
    set(fuzzing_flags ${CXXFLAGS})
  # Set the flag to enable code coverage instrumentation. Fuzzing engines use
  # code coverage as a metric to guide the fuzzing. We use the basic code
  # coverage level (trace-pc). This flag has different values in CLANG and GNU.
  # Other values, such as trace-cmp, can be used to trace data flow. See the
  # official documentation for the compiler flags.
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # TODO(minafarid): Check the version of CLANG. CLANG versions >= 5.0 should
    # have libFuzzer by default.
    set(fuzzing_flags -fsanitize-coverage=trace-pc-guard)
  elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    set(fuzzing_flags -fsanitize-coverage=trace-pc)
  else()
    message(FATAL_ERROR "The compiler ${CMAKE_CXX_COMPILER_ID} does not support fuzzing.")
  endif()

  foreach(flag ${fuzzing_flags})
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${flag}")
  endforeach()
endif()
