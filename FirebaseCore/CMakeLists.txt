# Copyright 2019 Google LLC
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

if(NOT APPLE)
  return()
endif()

file(GLOB sources Sources/*.m)
file(GLOB headers Sources/Private/*.h Sources/Public/*.h)

podspec_version(version ${PROJECT_SOURCE_DIR}/FirebaseCore.podspec)
firebase_version(firebase_ios_version ${PROJECT_SOURCE_DIR}/FirebaseCore.podspec)

firebase_ios_objc_framework(
  FirebaseCore
  SOURCES ${sources}
  HEADERS ${headers}
  VERSION ${version}
  DEFINES
    FIRCore_VERSION=${version}
    Firebase_VERSION=${firebase_ios_version}
  INCLUDES
    ${PROJECT_SOURCE_DIR}
  DEPENDS
    FirebaseCoreDiagnosticsInterop
    GoogleUtilities
    "-framework Foundation"
  DISABLE_STRICT_WARNINGS
  EXCLUDE_FROM_ALL
)

if(IOS)
  target_link_libraries(FirebaseCore PRIVATE "-framework UIKit")
elseif(APPLE)
  target_link_libraries(FirebaseCore PRIVATE "-framework AppKit")
endif()
