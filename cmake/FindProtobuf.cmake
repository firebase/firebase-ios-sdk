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

include(FindPackageHandleStandardArgs)

set(BINARY_DIR ${FIREBASE_INSTALL_DIR}/external/protobuf)

find_path(
  PROTOBUF_INCLUDE_DIR google/protobuf/stubs/common.h
  HINTS ${BINARY_DIR}/src/protobuf/src
)

find_library(
  PROTOBUF_LIBRARY
  NAMES protobuf protobufd
  HINTS ${BINARY_DIR}/src/protobuf-build
)

find_library(
  PROTOBUFLITE_LIBRARY
  NAMES protobuf-lite protobuf-lited
  HINTS ${BINARY_DIR}/src/protobuf-build
)

find_package_handle_standard_args(
  protobuf
  DEFAULT_MSG
  PROTOBUF_INCLUDE_DIR
  PROTOBUF_LIBRARY
  PROTOBUFLITE_LIBRARY
)

if(PROTOBUF_FOUND)
  set(PROTOBUF_INCLUDE_DIRS ${PROTOBUF_INCLUDE_DIR})
  set(PROTOBUF_LIBRARIES ${PROTOBUF_LIBRARY} ${PROTOBUFLITE_LIBRARY})

  if (NOT TARGET protobuf-lite)
    add_library(protobuf-lite UNKNOWN IMPORTED)
    set_target_properties(
      protobuf-lite PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${PROTOBUF_INCLUDE_DIRS}
      IMPORTED_LOCATION ${PROTOBUFLITE_LIBRARY}
    )
  endif()
  if (NOT TARGET protobuf)
    add_library(protobuf UNKNOWN IMPORTED)
    set_target_properties(
      protobuf PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${PROTOBUF_INCLUDE_DIRS}
      IMPORTED_LOCATION ${PROTOBUF_LIBRARY}
      INTERFACE_LINK_LIBRARIES protobuf-lite
    )
  endif()
endif(PROTOBUF_FOUND)
