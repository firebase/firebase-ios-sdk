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
  firebase_firestore_remote_test
  SOURCES
    exponential_backoff_test.cc
    grpc_connection_test.cc
    grpc_stream_test.cc
    grpc_streaming_reader_test.cc
    grpc_unary_call_test.cc
    serializer_test.cc
    watch_change_test.mm
  DEPENDS
    absl_base
    firebase_firestore_protos_libprotobuf
    firebase_firestore_core
    firebase_firestore_remote
    firebase_firestore_remote_test_util
    firebase_firestore_util_async_std
)
