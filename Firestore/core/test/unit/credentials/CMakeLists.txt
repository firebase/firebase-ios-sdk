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

file(GLOB sources *.cc *.h)
firebase_ios_add_test(firestore_credentials_test ${sources})

target_link_libraries(
  firestore_credentials_test PRIVATE
  firestore_core
)

if(APPLE)
  target_sources(
    firestore_credentials_test PRIVATE
    firebase_app_check_credentials_provider_test.mm
    firebase_auth_credentials_provider_test.mm
  )

  target_link_libraries(
    firestore_credentials_test PRIVATE
    firestore_testutil
  )
endif()
