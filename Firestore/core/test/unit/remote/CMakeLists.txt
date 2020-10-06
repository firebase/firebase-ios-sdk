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

file(
  GLOB remote_testing_sources
  create_noop_connectivity_monitor.*
  fake_target_metadata_provider.*
)

firebase_ios_add_library(
  firestore_remote_testing EXCLUDE_FROM_ALL
  ${remote_testing_sources}
)

target_link_libraries(
  firestore_remote_testing PUBLIC
  absl_memory
  firestore_core
)


firebase_ios_glob(
  sources *.cc *.h
  EXCLUDE ${remote_testing_sources}
)

firebase_ios_add_test(firestore_remote_test ${sources})

target_link_libraries(
  firestore_remote_test PRIVATE
  GMock::GMock
  absl_base
  firestore_core
  firestore_protos_protobuf
  firestore_remote_testing
  firestore_testutil
)
