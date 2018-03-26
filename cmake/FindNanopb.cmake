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

set(BINARY_DIR ${FIREBASE_INSTALL_DIR}/external/nanopb)

find_path(
  NANOPB_INCLUDE_DIR pb.h
  HINTS ${BINARY_DIR}/src/nanopb
)

find_library(
  NANOPB_LIBRARY
  NAMES protobuf-nanopb protobuf-nanopbd
  HINTS ${BINARY_DIR}/src/nanopb
)

find_package_handle_standard_args(
  nanopb
  DEFAULT_MSG
  NANOPB_INCLUDE_DIR
  NANOPB_LIBRARY
)

if(NANOPB_FOUND)
  set(NANOPB_INCLUDE_DIRS ${NANOPB_INCLUDE_DIR})

  if (NOT TARGET nanopb)
    add_library(nanopb UNKNOWN IMPORTED)
    set_target_properties(
      nanopb PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${NANOPB_INCLUDE_DIRS}
      IMPORTED_LOCATION ${NANOPB_LIBRARY}
    )
  endif()
endif(NANOPB_FOUND)
