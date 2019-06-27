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
    document.cc
    document.h
    document_key.cc
    document_key.h
    document_key_set.h
    document_map.h
    document_map.mm
    document_set.h
    document_set.mm
    field_mask.h
    field_mask.cc
    field_path.cc
    field_path.h
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
    no_document.cc
    no_document.h
    precondition.cc
    precondition.h
    resource_path.cc
    resource_path.h
    snapshot_version.cc
    snapshot_version.h
    transform_operations.h
    transform_operations.mm
    types.h
    unknown_document.cc
    unknown_document.h
  DEPENDS
    # TODO(b/111328563) Force nanopb first to work around ODR violations
    firebase_firestore_nanopb

    absl_optional
    absl_strings
    firebase_firestore_api_input_validation
    firebase_firestore_immutable
    firebase_firestore_objc
    firebase_firestore_util
    firebase_firestore_types
)
