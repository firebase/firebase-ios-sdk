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
  firebase_firestore_model_test
  SOURCES
    database_id_test.cc
    document_key_test.cc
    document_set_test.cc
    document_test.cc
    field_mask_test.cc
    field_path_test.cc
    field_transform_test.cc
    field_value_test.cc
    mutation_test.cc
    no_document_test.cc
    precondition_test.cc
    resource_path_test.cc
    snapshot_version_test.cc
    transform_operation_test.cc
  DEPENDS
    firebase_firestore_model
    firebase_firestore_testutil
    GMock::GMock
)

cc_binary(
  firebase_firestore_model_field_value_benchmark
  SOURCES
    field_value_benchmark.cc
  DEPENDS
    absl::variant
    benchmark
    benchmark_main
    firebase_firestore_model
    firebase_firestore_testutil
)
