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
  firebase_firestore_remote_connectivity_monitor_apple
  SOURCES
    connectivity_monitor.cc
    connectivity_monitor.h
    connectivity_monitor_apple.mm
  DEPENDS
    absl_base
    firebase_firestore_util
  EXCLUDE_FROM_ALL
)

cc_library(
  firebase_firestore_remote_connectivity_monitor_noop
  SOURCES
    connectivity_monitor.cc
    connectivity_monitor.h
    connectivity_monitor_noop.cc
  DEPENDS
    absl_base
    firebase_firestore_util
  EXCLUDE_FROM_ALL
)

cc_select(
  firebase_firestore_remote_connectivity_monitor
  APPLE   firebase_firestore_remote_connectivity_monitor_apple
  DEFAULT firebase_firestore_remote_connectivity_monitor_noop
)

cc_library(
  firebase_firestore_remote
  SOURCES
    grpc_util.h
    grpc_util.cc
    exponential_backoff.h
    exponential_backoff.cc
    serializer.h
    serializer.cc
  DEPENDS
    # TODO(b/111328563) Force nanopb first to work around ODR violations
    protobuf-nanopb

    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_remote_connectivity_monitor
    firebase_firestore_util
    grpc
)
