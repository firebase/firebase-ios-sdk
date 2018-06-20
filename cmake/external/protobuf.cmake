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

include(ExternalProject)

# Protubuf has CMake support, but includes it in a `cmake` subdirectory, which
# does not work with CMake's ExternalProject by default. CMake 3.7 added
# SOURCE_SUBDIR as a means of supporting this but that's too new to require
# yet.

# Compose CMAKE_ARGS
set(
  cmake_args
  -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
  -DBUILD_SHARED_LIBS:BOOL=OFF
  -Dprotobuf_BUILD_TESTS:BOOL=OFF
  -Dprotobuf_WITH_ZLIB:BOOL=OFF
  -Dprotobuf_MSVC_STATIC_RUNTIME:BOOL=ON
)

# For single-configuration generators, pass CONFIG at configure time
if(NOT CMAKE_CONFIGURATION_TYPES)
  list(APPEND cmake_args -DCMAKE_BUILD_TYPE=$<CONFIG>)
endif()


if(CMAKE_VERSION VERSION_LESS "3.7")
  # Manually compose the commands required to invoke CMake in the external
  # project.
  #
  # Compose CONFIGURE_COMMAND so as to preserve the outer CMake's generator
  # configuration in the sub-build. Without this the builds can invoke
  # different compilers or disagree about word size or other fundamental
  # parameters making the output of the sub-build useless. This is based on
  # _ep_extract_configure_command in ExternalProject.cmake.
  set(configure "${CMAKE_COMMAND}")

  if(CMAKE_EXTRA_GENERATOR)
    list(APPEND configure "-G${CMAKE_EXTRA_GENERATOR} - ${CMAKE_GENERATOR}")
  else()
    list(APPEND configure "-G${CMAKE_GENERATOR}")
  endif()

  if(CMAKE_GENERATOR_PLATFORM)
    list(APPEND configure "-A${CMAKE_GENERATOR_PLATFORM}")
  endif()

  if(CMAKE_GENERATOR_TOOLSET)
    list(APPEND configure "-T${CMAKE_GENERATOR_TOOLSET}")
  endif()

  list(
    APPEND configure
    ${cmake_args}
    "${PROJECT_BINARY_DIR}/external/protobuf/src/protobuf/cmake"
  )

  # Compose BUILD_COMMAND and INSTALL_COMMAND
  set(build "${CMAKE_COMMAND}" --build .)

  # For multi-configuration generators, pass CONFIG at build time.
  if(CMAKE_CONFIGURATION_TYPES)
    list(APPEND build --config $<CONFIG>)
  endif()

  set(install ${build} --target install)

  set(
    commands
    CONFIGURE_COMMAND ${configure}
    BUILD_COMMAND ${build}
    INSTALL_COMMAND ${install}
  )

else()
  # CMake 3.7 and above support this directly.
  set(
    commands
    CMAKE_ARGS ${cmake_args}
    SOURCE_SUBDIR cmake
  )
endif()

ExternalProject_Add(
  protobuf

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME protobuf-v3.5.1.1.tar.gz
  URL https://github.com/google/protobuf/archive/v3.5.1.1.tar.gz
  URL_HASH SHA256=56b5d9e1ab2bf4f5736c4cfba9f4981fbc6976246721e7ded5602fbaee6d6869

  PREFIX ${PROJECT_BINARY_DIR}/external/protobuf
  INSTALL_DIR ${FIREBASE_INSTALL_DIR}

  ${commands}

  UPDATE_COMMAND ""
  TEST_COMMAND ""
)
