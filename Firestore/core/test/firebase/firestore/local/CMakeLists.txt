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

cc_test(
  firebase_firestore_local_test
  SOURCES
    #index_manager_test.mm
    #leveldb_index_manager_test.mm
    leveldb_key_test.cc
    leveldb_util_test.cc
    local_serializer_test.cc
    #memory_index_manager_test.mm
  DEPENDS
    firebase_firestore_core
    firebase_firestore_local
    firebase_firestore_local_persistence_leveldb
    firebase_firestore_model
    firebase_firestore_protos_libprotobuf
    firebase_firestore_testutil
)
