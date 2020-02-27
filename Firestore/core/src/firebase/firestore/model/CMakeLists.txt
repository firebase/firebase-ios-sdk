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
  firebase_firestore_model
  SOURCES
    base_path.h
    database_id.cc
    database_id.h
    delete_mutation.cc
    delete_mutation.h
    document.cc
    document.h
    model_fwd.h
    document_key.cc
    document_key.h
    document_key_set.h
    document_map.cc
    document_map.h
    document_set.cc
    document_set.h
    field_mask.cc
    field_mask.h
    field_path.cc
    field_path.h
    field_transform.cc
    field_transform.h
    field_value.cc
    field_value.h
    field_value_options.h
    maybe_document.cc
    maybe_document.h
    mutation.cc
    mutation.h
    mutation_batch.cc
    mutation_batch.h
    mutation_batch_result.cc
    mutation_batch_result.h
    no_document.cc
    no_document.h
    patch_mutation.cc
    patch_mutation.h
    precondition.cc
    precondition.h
    resource_path.cc
    resource_path.h
    set_mutation.cc
    set_mutation.h
    snapshot_version.cc
    snapshot_version.h
    transform_mutation.cc
    transform_mutation.h
    transform_operation.cc
    transform_operation.h
    types.h
    unknown_document.cc
    unknown_document.h
    verify_mutation.cc
    verify_mutation.h
  DEPENDS
    absl_optional
    absl_strings
    firebase_firestore_immutable
    firebase_firestore_nanopb
    firebase_firestore_objc
    firebase_firestore_util
    firebase_firestore_types
)
