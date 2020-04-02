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

if(APPLE)
  firebase_ios_objc_test(
    firebase_firestore_objc_spec_test
    HOST firebase_firestore_example_app
    SOURCES
      FSTLevelDBSpecTests.mm
      FSTMemorySpecTests.mm
      FSTMockDatastore.h
      FSTMockDatastore.mm
      FSTSpecTests.h
      FSTSpecTests.mm
      FSTSyncEngineTestDriver.h
      FSTSyncEngineTestDriver.mm
    DEPENDS
      FirebaseFirestore
      firebase_firestore_objc_test_util
      firebase_firestore_remote_testing
      firestore_local_testing
    # Force this to run in the project-wide binary directory so that relative
    # paths used during compilation are usable.
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
  )
endif(APPLE)
