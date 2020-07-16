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

# TODO(wilhuff): Resolve FSTGoogleTestTests.mm NOLINT(not built)
#
# FSTGoogleTestTests.mm is a bridge for running GoogleTest-based tests within
# Xcode, but that's not necessary in CMake which directly supports running
# GoogleTest-based tests.

if(NOT FIREBASE_IOS_BUILD_TESTS)
  return()
endif()

file(GLOB sources *.cc)  # not .mm
firebase_ios_add_test(firestore_types_test ${sources})

target_link_libraries(
  firestore_types_test PRIVATE
  absl_time
  firestore_core
)
