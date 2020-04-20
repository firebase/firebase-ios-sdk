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

if(IOS)
  file(GLOB sources iOS/*.h iOS/*.m)
  firebase_ios_add_executable(firestore_objc_host_app MACOSX_BUNDLE ${sources})

  target_link_libraries(
    firestore_objc_host_app PRIVATE
    "-framework Foundation"
    "-framework UIKit"
  )

  set_target_properties(
    firestore_objc_host_app PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/iOS/Firestore-Info.plist
    RESOURCE GoogleService-Info.plist
  )

else()
  # Assume macOS

  file(GLOB sources macOS/*.h macOS/*.m)
  firebase_ios_add_executable(firestore_objc_host_app MACOSX_BUNDLE ${sources})

  target_link_libraries(
    firestore_objc_host_app PRIVATE
    "-framework AppKit"
    "-framework Foundation"
  )

  set_target_properties(
    firestore_objc_host_app PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/macOS/Info.plist
    RESOURCE GoogleService-Info.plist
  )
endif()
