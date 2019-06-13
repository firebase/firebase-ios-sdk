# Copyright 2019 Google
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
  firebase_firestore_api_input_validation_std
  SOURCES
    input_validation.h
    input_validation_std.cc
  DEPENDS
    firebase_firestore_util
)

cc_library(
  firebase_firestore_api_input_validation_apple
  SOURCES
    input_validation.h
    input_validation_apple.mm
  DEPENDS
    firebase_firestore_util
)

cc_select(
  firebase_firestore_api_input_validation
  APPLE   firebase_firestore_api_input_validation_apple
  DEFAULT firebase_firestore_api_input_validation_std
)

cc_library(
  firebase_firestore_api
  SOURCES
    collection_reference.h
    collection_reference.mm
    query_core.h
    query_core.mm
    settings.cc
    settings.h
    snapshot_metadata.cc
    snapshot_metadata.h
  DEPENDS
    absl_meta
    firebase_firestore_api_input_validation
    firebase_firestore_core
    firebase_firestore_model
    firebase_firestore_util
)
