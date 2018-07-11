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

# C++ Compiler setup

include(compiler_id)

# We use C++11
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(CMAKE_GENERATOR STREQUAL "Ninja")
  set(NINJA ON)
endif()

if(CXX_CLANG OR CXX_GNU)
  set(
    common_flags
    -Wall -Wextra -Werror

    # Be super pedantic about format strings
    -Wformat

    # Avoid use of uninitialized values
    -Wuninitialized
    -fno-common

    # Delete unused things
    -Wunused-function -Wunused-value -Wunused-variable
  )

  set(
    cxx_flags

    # Cut down on symbol clutter
    # TODO(wilhuff) try -fvisibility=hidden
    -fvisibility-inlines-hidden
  )

  set(
    c_flags
    -Wstrict-prototypes
  )

  if(CXX_CLANG)
    list(
      APPEND common_flags
     -Wconditional-uninitialized -Werror=return-type -Winfinite-recursion -Wmove
     -Wrange-loop-analysis -Wunreachable-code

     # Options added to match apple recommended project settings
     -Wcomma
    )
  endif()

  if(NINJA)
    # If building under Ninja, disable tty detection and force color output
    if(CXX_CLANG OR CXX_GNU)
      list(APPEND common_flags -fdiagnostics-color)
    endif()
  endif()

  foreach(flag ${common_flags} ${c_flags})
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${flag}")
  endforeach()

  foreach(flag ${common_flags} ${cxx_flags})
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${flag}")
  endforeach()
endif()

if(APPLE)
  # CMake has no special support for Objective-C as a distinct language but
  # enabling modules and other clang extensions would apply even to regular C++
  # sources which is nonportable. Keep these flags separate to avoid misuse.
  set(
    OBJC_FLAGS
    -Werror=deprecated-objc-isa-usage
    -Werror=non-modular-include-in-framework-module
    -Werror=objc-root-class

    -Wblock-capture-autoreleasing
    -Wimplicit-atomic-properties
    -Wnon-modular-include-in-framework-module

    -fobjc-arc
    -fmodules
    -fno-autolink

    -F${FIREBASE_INSTALL_DIR}/Frameworks
  )
endif()
