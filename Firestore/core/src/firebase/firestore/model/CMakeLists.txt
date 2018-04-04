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
    field_mask.h
    field_path.cc
    field_path.h
    field_value.cc
    field_value.h
    maybe_document.cc
    maybe_document.h
    no_document.cc
    no_document.h
    resource_path.cc
    resource_path.h
    snapshot_version.cc
    snapshot_version.h
    types.h
  DEPENDS
    absl_strings
    firebase_firestore_util
    firebase_firestore_types
)
