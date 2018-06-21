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

find_library(
  GoogleUtilities_LIBRARY
  GoogleUtilities
  PATHS ${FIREBASE_INSTALL_DIR}/Frameworks
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  GoogleUtilities
  DEFAULT_MSG
  GoogleUtilities_LIBRARY
)

if(GoogleUtilities_FOUND)
  # Emulate CocoaPods behavior which makes all headers available unqualified.
  set(
    GoogleUtilities_INCLUDE_DIRS
    ${GoogleUtilities_LIBRARY}/Headers
    ${GoogleUtilities_LIBRARY}/PrivateHeaders
  )

  set(
    GoogleUtilities_LIBRARIES
    ${GoogleUtilities_LIBRARY}
    "-framework Foundation"
  )

  if(NOT TARGET GoogleUtilities)
    # Add frameworks as INTERFACE libraries rather than IMPORTED so that
    # framework behavior is preserved.
    add_library(GoogleUtilities INTERFACE)

    set_property(
      TARGET GoogleUtilities APPEND PROPERTY
      INTERFACE_INCLUDE_DIRECTORIES ${GoogleUtilities_INCLUDE_DIRS}
    )
    set_property(
      TARGET GoogleUtilities APPEND PROPERTY
      INTERFACE_LINK_LIBRARIES ${GoogleUtilities_LIBRARIES}
    )
  endif()
endif(GoogleUtilities_FOUND)
