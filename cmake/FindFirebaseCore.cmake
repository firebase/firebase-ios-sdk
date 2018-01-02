# Copyright 2017 Google
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
  FIREBASECORE_LIBRARY
  FirebaseCore
  PATHS ${FIREBASE_BINARY_DIR}/Frameworks
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  FirebaseCore
  DEFAULT_MSG
  FIREBASECORE_LIBRARY
)

if(FIREBASECORE_FOUND)
  # Emulate CocoaPods behavior which makes all headers available unqualified.
  set(
    FIREBASECORE_INCLUDE_DIRS
    ${FIREBASECORE_LIBRARY}/Headers
    ${FIREBASECORE_LIBRARY}/PrivateHeaders
  )

  set(
    FIREBASECORE_LIBRARIES
    ${FIREBASECORE_LIBRARY}
    "-framework Foundation"
  )

  if(NOT TARGET FirebaseCore)
    # Add frameworks as INTERFACE libraries rather than IMPORTED so that
    # framework behavior is preserved.
    add_library(FirebaseCore INTERFACE)

    set_property(
      TARGET FirebaseCore APPEND PROPERTY
      INTERFACE_INCLUDE_DIRECTORIES ${FIREBASECORE_INCLUDE_DIRS}
    )
    set_property(
      TARGET FirebaseCore APPEND PROPERTY
      INTERFACE_LINK_LIBRARIES ${FIREBASECORE_LIBRARIES}
    )
  endif()
endif(FIREBASECORE_FOUND)
