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
  firebase_firestore_local
  SOURCES
    leveldb_key.h
    leveldb_key.cc
    leveldb_transaction.h
    leveldb_transaction.cc
    local_serializer.h
    local_serializer.cc
  DEPENDS
    LevelDB::LevelDB
    absl_strings
    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_remote
    firebase_firestore_util
    nanopb
)
