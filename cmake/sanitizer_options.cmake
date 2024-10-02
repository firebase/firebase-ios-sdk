# Copyright 2018 Google LLC
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

# Adds Sanitzer options to the current build.

option(WITH_ASAN "Build with Address Sanitizer" OFF)
# TODO(varconst): msan
# Memory sanitizer is more complicated:
# - it requires all dependencies to be compiled with msan enabled (see
#   https://github.com/google/sanitizers/wiki/MemorySanitizerLibcxxHowTo);
# - AppleClang doesn't support it.
option(WITH_TSAN "Build with Thread Sanitizer (mutually exclusive with other sanitizers)" OFF)
option(WITH_UBSAN "Build with Undefined Behavior sanitizer" OFF)

macro(add_to_compile_and_link_flags flag)
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${flag}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${flag}")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${flag}")
  set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} ${flag}")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${flag}")
endmacro()

if(CXX_CLANG OR CXX_GNU)
  if(WITH_ASAN)
    add_to_compile_and_link_flags("-fsanitize=address")
  endif()

  if(WITH_TSAN)
    if(WITH_ASAN OR WITH_UBSAN)
      message(FATAL_ERROR "Cannot combine TSan with other sanitizers")
    endif()
    add_to_compile_and_link_flags("-fsanitize=thread")
  endif()

  if(WITH_UBSAN)
    add_to_compile_and_link_flags("-fsanitize=undefined")
  endif()

  if (WITH_ASAN OR WITH_TSAN OR WITH_UBSAN)
    # Recommended to "get nicer stack traces in error messages"
    # TODO(varconst): double-check that TSan actually needs this flag (it's
    # explicitly recommended in the docs for ASan and UBSan)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-omit-frame-pointer")
  endif()
else()
  if(WITH_ASAN OR WITH_TSAN OR WITH_UBSAN)
    message(FATAL_ERROR "Only Clang and GCC support sanitizers")
  endif()
endif()
