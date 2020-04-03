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
  firebase_firestore_nanopb_runtime
  SOURCES
    byte_string.cc
    byte_string.h
    nanopb_util.cc
    nanopb_util.h
    pretty_printing.cc
    pretty_printing.h

  DEPENDS
    absl_strings
    firebase_firestore_util
    protobuf-nanopb-static
)

firebase_ios_cc_library(
  firebase_firestore_nanopb
  SOURCES
    fields_array.h
    message.cc
    message.h
    reader.cc
    reader.h
    writer.cc
    writer.h
  DEPENDS
    firebase_firestore_nanopb_runtime
    firebase_firestore_util
    firestore_protos_nanopb
    grpc++
    protobuf-nanopb-static
)

target_compile_definitions(
  firebase_firestore_nanopb
  PUBLIC -DPB_ENABLE_MALLOC
)
