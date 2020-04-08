# Copyright 2018 Google LLC
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
  firebase_firestore_remote_testing
  SOURCES
    create_noop_connectivity_monitor.cc
    create_noop_connectivity_monitor.h
    fake_target_metadata_provider.cc
    fake_target_metadata_provider.h
  DEPENDS
    absl_memory
    firebase_firestore_remote
)

firebase_ios_cc_test(
  firebase_firestore_remote_test
  SOURCES
    datastore_test.cc
    exponential_backoff_test.cc
    fake_credentials_provider.cc
    fake_credentials_provider.h
    grpc_connection_test.cc
    grpc_stream_test.cc
    grpc_stream_tester.cc
    grpc_stream_tester.h
    grpc_streaming_reader_test.cc
    grpc_unary_call_test.cc
    remote_event_test.cc
    serializer_test.cc
    stream_test.cc
    watch_change_test.cc

  DEPENDS
    GMock::GMock
    absl_base
    firebase_firestore_protos_libprotobuf
    firebase_firestore_core
    firebase_firestore_local
    firebase_firestore_remote
    firebase_firestore_remote_testing
    firebase_firestore_util_async_std
    firestore_testutil
)
