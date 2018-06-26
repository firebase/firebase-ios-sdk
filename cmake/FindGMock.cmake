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

find_path(
  GMOCK_INCLUDE_DIR gmock/gmock.h
  HINTS ${FIREBASE_INSTALL_DIR}/include
)

find_library(
  GMOCK_LIBRARY
  NAMES gmock
  HINTS ${FIREBASE_INSTALL_DIR}/lib
)

find_package_handle_standard_args(
  gmock
  DEFAULT_MSG
  GMOCK_INCLUDE_DIR
  GMOCK_LIBRARY
)

if(GMOCK_FOUND)
  set(GMOCK_INCLUDE_DIRS ${GMOCK_INCLUDE_DIR})
  set(GMOCK_LIBRARIES ${GMOCK_LIBRARY})

  if (NOT TARGET GMock::GMock)
    add_library(GMock::GMock UNKNOWN IMPORTED)
    set_target_properties(
      GMock::GMock PROPERTIES
      INTERFACE_INCLUDE_DIRECTORIES ${GMOCK_INCLUDE_DIRS}
      IMPORTED_LOCATION ${GMOCK_LIBRARY}
    )
  endif()
endif(GMOCK_FOUND)
