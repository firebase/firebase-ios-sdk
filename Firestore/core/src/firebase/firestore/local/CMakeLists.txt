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
  firebase_firestore_local_base
  SOURCES
    document_key_reference.cc
    document_key_reference.h
    index_manager.h
    local_serializer.cc
    local_serializer.h
    lru_garbage_collector.cc
    lru_garbage_collector.h
    memory_index_manager.cc
    memory_index_manager.h
    query_data.cc
    query_data.h
    reference_set.cc
    reference_set.h
  DEPENDS
    absl_strings
    firebase_firestore_core_query
    firebase_firestore_immutable
    firebase_firestore_model
    firebase_firestore_remote_serializer
  EXCLUDE_FROM_ALL
)


cc_library(
  firebase_firestore_local_persistence_leveldb
  SOURCES
    leveldb_index_manager.cc
    leveldb_index_manager.h
    leveldb_key.cc
    leveldb_key.h
    leveldb_lru_reference_delegate.cc
    leveldb_lru_reference_delegate.h
    leveldb_migrations.cc
    leveldb_migrations.h
    leveldb_mutation_queue.cc
    leveldb_mutation_queue.h
    leveldb_persistence.cc
    leveldb_persistence.h
    leveldb_query_cache.cc
    leveldb_query_cache.h
    leveldb_remote_document_cache.cc
    leveldb_remote_document_cache.h
    leveldb_transaction.cc
    leveldb_transaction.h
    leveldb_util.cc
    leveldb_util.h
  DEPENDS
    LevelDB::LevelDB
    absl_memory
    absl_strings
    firebase_firestore_local_base
    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_util
    protobuf-nanopb-static
  EXCLUDE_FROM_ALL
)

cc_library(
  firebase_firestore_local
  SOURCES
    document_key_reference.cc
    document_key_reference.h
    index_free_query_engine.h
    index_free_query_engine.cc
    index_manager.h
    listen_sequence.h
    local_documents_view.cc
    local_documents_view.h
    local_store.cc
    local_store.h
    local_view_changes.cc
    local_view_changes.h
    local_write_result.h
    memory_eager_reference_delegate.cc
    memory_eager_reference_delegate.h
    memory_lru_reference_delegate.cc
    memory_lru_reference_delegate.h
    memory_mutation_queue.cc
    memory_mutation_queue.h
    memory_persistence.cc
    memory_persistence.h
    memory_query_cache.cc
    memory_query_cache.h
    memory_remote_document_cache.cc
    memory_remote_document_cache.h
    mutation_queue.h
    persistence.h
    proto_sizer.cc
    proto_sizer.h
    query_cache.h
    query_engine.h
    reference_delegate.h
    remote_document_cache.h
    simple_query_engine.cc
    simple_query_engine.h
    sizer.h
  DEPENDS
    absl_strings
    firebase_firestore_auth
    firebase_firestore_core_query
    firebase_firestore_core_target_id_generator
    firebase_firestore_core_view
    firebase_firestore_local_base
    firebase_firestore_local_persistence_leveldb
    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_util
    protobuf-nanopb-static
)
