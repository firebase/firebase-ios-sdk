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

cc_library(
  firebase_firestore_testutil_apple
  SOURCES
    app_testing.h
    app_testing.mm
  DEPENDS
    FirebaseCore
    absl_strings
  EXCLUDE_FROM_ALL
)

if(APPLE)
  list(APPEND TESTUTIL_DEPENDS firebase_firestore_testutil_apple)
endif()

add_library(
  firebase_firestore_testutil INTERFACE
)
target_link_libraries(
  firebase_firestore_testutil INTERFACE
  ${TESTUTIL_DEPENDS}
)
