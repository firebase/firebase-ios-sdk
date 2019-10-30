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
  firebase_firestore_nanopb
  SOURCES
    byte_string.cc
    byte_string.h
    fields_array.h
    message.cc
    message.h
    nanopb_util.cc
    nanopb_util.h
    reader.cc
    reader.h
    writer.cc
    writer.h
  DEPENDS
    # TODO(b/111328563) Force nanopb first to work around ODR violations
    protobuf-nanopb-static

    firebase_firestore_model
    firebase_firestore_util
    firebase_firestore_protos_nanopb
    grpc++
)

target_compile_definitions(
  firebase_firestore_nanopb
  PUBLIC -DPB_ENABLE_MALLOC
)
