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

# C++ Compiler setup

# We use C++14
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  set(CXX_CLANG ON)
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set(CXX_GNU ON)
endif()

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
    -Wreorder -Werror=reorder
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
     # TODO(wilhuff): re-enable -Wcomma once Abseil fixes the definition of
     # ABSL_ASSERT upstream
     -Wno-comma
    )
  endif()

  if(NINJA)
    # If building under Ninja, disable tty detection and force color output
    if(CXX_CLANG OR CXX_GNU)
      list(APPEND common_flags -fdiagnostics-color)
    endif()
  endif()
endif()

if(APPLE)
  # CMake has no special support for Objective-C as a distinct language but
  # enabling modules and other clang extensions would apply even to regular C++
  # sources which is nonportable. Keep these flags separate to avoid misuse.
  set(
    FIREBASE_IOS_OBJC_FLAGS
    -fobjc-arc
    -fno-autolink
  )
  set(
    FIREBASE_IOS_OBJC_FLAGS_STRICT
    ${FIREBASE_IOS_OBJC_FLAGS}

    -Werror=deprecated-objc-isa-usage
    -Werror=non-modular-include-in-framework-module
    -Werror=objc-root-class

    -Wblock-capture-autoreleasing
    -Wimplicit-atomic-properties
    -Wnon-modular-include-in-framework-module
  )
endif()

if(MSVC)
  set(
    common_flags

    # Cut down on symbol cruft in windows.h
    /DWIN32_LEAN_AND_MEAN=1
    /DNOMINMAX=1

    # Specify at least Windows Vista/Server 2008 (required by gRPC)
    /D_WIN32_WINNT=0x600

    # Disable warnings that can't be easily addressed or are ignored by
    # upstream projects.

    # unary minus operator applied to unsigned type, result still unsigned
    /wd4146

    # character cannot be represented in the current code page
    /wd4566
  )
endif()

foreach(flag ${common_flags} ${c_flags})
  list(APPEND FIREBASE_IOS_C_FLAGS_STRICT ${flag})
endforeach()

foreach(flag ${common_flags} ${cxx_flags})
  list(APPEND FIREBASE_IOS_CXX_FLAGS_STRICT ${flag})
endforeach()

if(APPLE)
  # When building on Apple platforms, ranlib complains about "file has no
  # symbols". Unfortunately, most of our dependencies implement their
  # cross-platform build with preprocessor symbols so translation units that
  # don't target the current platform end up empty (and trigger this warning).
  set(CMAKE_C_ARCHIVE_CREATE   "<CMAKE_AR> Scr <TARGET> <LINK_FLAGS> <OBJECTS>")
  set(CMAKE_CXX_ARCHIVE_CREATE "<CMAKE_AR> Scr <TARGET> <LINK_FLAGS> <OBJECTS>")
  set(CMAKE_C_ARCHIVE_FINISH   "<CMAKE_RANLIB> -no_warning_for_no_symbols -c <TARGET>")
  set(CMAKE_CXX_ARCHIVE_FINISH "<CMAKE_RANLIB> -no_warning_for_no_symbols -c <TARGET>")
endif()
