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

# Downloads and builds libFuzzer from its sources. Uses the build.sh script
# provided by libFuzzer to compile the sources and produce a library with the
# name libFuzzer.a in the same directory as the sources because we have
# BUILD_IN_SOURCES set to TRUE.

# This build method might not work on all systems. See the build.sh script of
# libFuzzer here:
# (https://github.com/llvm-mirror/compiler-rt/blob/master/lib/fuzzer/build.sh).
# An alternative is to write own CMake file that builds libFuzzer.
include(ExternalProject)

if(TARGET libfuzzer)
  return()
endif()

# Mark libfuzzer target as done if: (a) fuzzing is not enabled and libFuzzer is
# not needed; (b) a fuzzing library is already provided in LIB_FUZZING_ENGINE
# environment variable as in OSS Fuzz and there is no need to build it; and
# (c) on Windows because fuzzing is not supported.
if(NOT FUZZING OR DEFINED ENV{LIB_FUZZING_ENGINE} OR WIN32)
  add_custom_target(libfuzzer)
  return()
endif()

set(tag RELEASE_601)  # latest release@{2018-07-27}

ExternalProject_Add(
  libfuzzer

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME libfuzzer
  SVN_REPOSITORY "https://llvm.org/svn/llvm-project/compiler-rt/tags/${tag}/final/lib/fuzzer"
  LOG_DOWNLOAD TRUE    # Do not print SVN checkout messages.

  PREFIX ${PROJECT_BINARY_DIR}

  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/libfuzzer
  BUILD_IN_SOURCE TRUE

  UPDATE_COMMAND    ""
  CONFIGURE_COMMAND ""
  BUILD_COMMAND     "${PROJECT_BINARY_DIR}/src/libfuzzer/build.sh"
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
)
