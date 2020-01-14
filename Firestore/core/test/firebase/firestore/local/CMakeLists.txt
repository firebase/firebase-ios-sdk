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
  firebase_firestore_local_testing
  SOURCES
    counting_query_engine.cc
    counting_query_engine.h
    persistence_testing.cc
    persistence_testing.h
  DEPENDS
    firebase_firestore_local
    firebase_firestore_local_persistence_leveldb
)

cc_test(
  firebase_firestore_local_test
  SOURCES
    index_free_query_engine_test.cc
    index_manager_test.cc
    index_manager_test.h
    leveldb_index_manager_test.cc
    leveldb_key_test.cc
    leveldb_local_store_test.cc
    leveldb_lru_garbage_collector_test.cc
    leveldb_migrations_test.cc
    leveldb_mutation_queue_test.cc
    leveldb_persistence_test.cc
    leveldb_remote_document_cache_test.cc
    leveldb_target_cache_test.cc
    leveldb_transaction_test.cc
    leveldb_util_test.cc
    local_serializer_test.cc
    local_store_test.cc
    local_store_test.h
    lru_garbage_collector_test.cc
    lru_garbage_collector_test.h
    memory_index_manager_test.cc
    memory_local_store_test.cc
    memory_lru_garbage_collector_test.cc
    memory_mutation_queue_test.cc
    memory_remote_document_cache_test.cc
    memory_target_cache_test.cc
    mutation_queue_test.cc
    mutation_queue_test.h
    reference_set_test.cc
    remote_document_cache_test.cc
    remote_document_cache_test.h
    target_cache_test.cc
    target_cache_test.h
  DEPENDS
    GMock::GMock
    firebase_firestore_auth
    firebase_firestore_core
    firebase_firestore_local
    firebase_firestore_local_persistence_leveldb
    firebase_firestore_local_testing
    firebase_firestore_model
    firebase_firestore_protos_libprotobuf
    firebase_firestore_remote_testing
    firebase_firestore_testutil
)
