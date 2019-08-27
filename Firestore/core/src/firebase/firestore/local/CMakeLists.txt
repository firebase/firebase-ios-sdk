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
  firebase_firestore_local_persistence_leveldb
  SOURCES
    leveldb_index_manager.h
    #leveldb_index_manager.mm
    leveldb_key.cc
    leveldb_key.h
    leveldb_migrations.cc
    leveldb_migrations.h
    leveldb_mutation_queue.h
    #leveldb_mutation_queue.mm
    leveldb_query_cache.h
    #leveldb_query_cache.mm
    leveldb_remote_document_cache.h
    #leveldb_remote_document_cache.mm
    leveldb_transaction.cc
    leveldb_transaction.h
    leveldb_util.cc
    leveldb_util.h
  DEPENDS
    # TODO(b/111328563) Force nanopb first to work around ODR violations
    protobuf-nanopb-static

    LevelDB::LevelDB
    absl_strings
    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_util
  EXCLUDE_FROM_ALL
)

cc_library(
  firebase_firestore_local
  SOURCES
    document_key_reference.cc
    document_key_reference.h
    index_manager.h
    listen_sequence.h
    local_documents_view.h
    local_documents_view.mm
    local_serializer.cc
    local_serializer.h
    local_view_changes.cc
    local_view_changes.h
    lru_garbage_collector.cc
    lru_garbage_collector.h
    memory_index_manager.cc
    memory_index_manager.h
    memory_mutation_queue.h
    #memory_mutation_queue.mm
    memory_query_cache.h
    #memory_query_cache.mm
    memory_remote_document_cache.h
    #memory_remote_document_cache.mm
    mutation_queue.h
    query_cache.h
    query_data.cc
    query_data.h
    reference_delegate.h
    reference_set.cc
    reference_set.h
    remote_document_cache.h
    sizer.h
  DEPENDS
    # TODO(b/111328563) Force nanopb first to work around ODR violations
    protobuf-nanopb-static

    absl_strings
    firebase_firestore_local_persistence_leveldb
    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_remote
    firebase_firestore_util
)
