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

if(HAVE_LEVELDB)
  cc_library(
    firebase_firestore_local_persistence_leveldb
    SOURCES
      leveldb_key.cc
      leveldb_key.h
      leveldb_migrations.cc
      leveldb_migrations.h
      leveldb_transaction.cc
      leveldb_transaction.h
      leveldb_util.cc
      leveldb_util.h
    DEPENDS
      # TODO(b/111328563) Force nanopb first to work around ODR violations
      protobuf-nanopb

      LevelDB::LevelDB
      absl_strings
      firebase_firestore_model
      firebase_firestore_nanopb
      firebase_firestore_protos_nanopb
      firebase_firestore_util
    EXCLUDE_FROM_ALL
  )

  set(
    FIREBASE_FIRESTORE_LOCAL_PERSISTENCE
    firebase_firestore_local_persistence_leveldb
  )
endif()

cc_library(
  firebase_firestore_local
  SOURCES
    document_reference.h
    document_reference.cc
    local_serializer.h
    local_serializer.cc
    query_data.cc
    query_data.h
    reference_set.cc
    reference_set.h
  DEPENDS
    # TODO(b/111328563) Force nanopb first to work around ODR violations
    protobuf-nanopb

    ${FIREBASE_FIRESTORE_LOCAL_PERSISTENCE}
    absl_strings
    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_remote
    firebase_firestore_util
)
