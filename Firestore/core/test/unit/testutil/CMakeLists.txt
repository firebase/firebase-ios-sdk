# Copyright 2018 Google LLC
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

if(NOT FIREBASE_IOS_BUILD_TESTS)
  return()
endif()

firebase_ios_glob(sources *.cc *.h EXCLUDE app_testing.h)
if(APPLE)
  firebase_ios_glob(sources APPEND app_testing.*)
endif()

firebase_ios_add_library(firestore_testutil EXCLUDE_FROM_ALL ${sources})

target_link_libraries(
  firestore_testutil
  GMock::GMock
  GTest::GTest
  absl_strings
  absl_time
  firestore_core
)

if(APPLE)
  target_link_libraries(
    firestore_testutil
    ${XCTest_LIBRARIES}
    FirebaseCore
  )
endif()
