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

if(NOT FIREBASE_IOS_BUILD_TESTS OR NOT APPLE)
  return()
endif()

file(GLOB sources *.h *.mm API/*.h API/*.mm ../../App/GoogleService-Info.plist)

firebase_ios_add_objc_test(
  firestore_objc_integration_test
  firestore_objc_host_app
  ${sources}
)

target_link_libraries(
  firestore_objc_integration_test PRIVATE
  FirebaseFirestore
  firestore_core
  firestore_objc_testing
)

set_target_properties(
  firestore_objc_integration_test PROPERTIES
  RESOURCE ../../App/GoogleService-Info.plist
)
