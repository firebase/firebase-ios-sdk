# Copyright 2019 Google LLC
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

firebase_ios_cc_library(
  firebase_firestore_api
  SOURCES
    api_fwd.h
    collection_reference.cc
    collection_reference.h
    document_change.cc
    document_change.h
    document_reference.cc
    document_reference.h
    document_snapshot.cc
    document_snapshot.h
    firestore.cc
    firestore.h
    listener_registration.h
    query_core.cc
    query_core.h
    query_listener_registration.cc
    query_listener_registration.h
    query_snapshot.cc
    query_snapshot.h
    settings.cc
    settings.h
    snapshot_metadata.cc
    snapshot_metadata.h
    snapshots_in_sync_listener_registration.cc
    snapshots_in_sync_listener_registration.h
    source.h
    write_batch.cc
    write_batch.h
  DEPENDS
    absl_meta
    firebase_firestore_core
    firebase_firestore_local
    firebase_firestore_model
    firebase_firestore_util
)
