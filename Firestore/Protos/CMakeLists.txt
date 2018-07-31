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
  firebase_firestore_protos_nanopb
  SOURCES
    nanopb/firestore/local/maybe_document.pb.c
    nanopb/firestore/local/maybe_document.nanopb.h
    nanopb/firestore/local/mutation.pb.c
    nanopb/firestore/local/mutation.nanopb.h
    nanopb/firestore/local/target.pb.c
    nanopb/firestore/local/target.nanopb.h
    nanopb/google/api/annotations.pb.c
    nanopb/google/api/annotations.nanopb.h
    nanopb/google/api/http.pb.c
    nanopb/google/api/http.nanopb.h
    nanopb/google/firestore/v1beta1/common.pb.c
    nanopb/google/firestore/v1beta1/common.nanopb.h
    nanopb/google/firestore/v1beta1/document.pb.c
    nanopb/google/firestore/v1beta1/document.nanopb.h
    nanopb/google/firestore/v1beta1/firestore.pb.c
    nanopb/google/firestore/v1beta1/firestore.nanopb.h
    nanopb/google/firestore/v1beta1/query.pb.c
    nanopb/google/firestore/v1beta1/query.nanopb.h
    nanopb/google/firestore/v1beta1/write.pb.c
    nanopb/google/firestore/v1beta1/write.nanopb.h
    nanopb/google/protobuf/any.pb.c
    nanopb/google/protobuf/any.nanopb.h
    nanopb/google/protobuf/empty.pb.c
    nanopb/google/protobuf/empty.nanopb.h
    nanopb/google/protobuf/struct.pb.c
    nanopb/google/protobuf/struct.nanopb.h
    nanopb/google/protobuf/timestamp.pb.c
    nanopb/google/protobuf/timestamp.nanopb.h
    nanopb/google/protobuf/wrappers.pb.c
    nanopb/google/protobuf/wrappers.nanopb.h
    nanopb/google/rpc/status.pb.c
    nanopb/google/rpc/status.nanopb.h
    nanopb/google/type/latlng.pb.c
    nanopb/google/type/latlng.nanopb.h
  DEPENDS
    protobuf-nanopb
)

target_include_directories(
  firebase_firestore_protos_nanopb
  PUBLIC ${FIREBASE_SOURCE_DIR}/Firestore/Protos/nanopb
)

# libprotobuf based generated protos. Expected only to be used in test (as
# libprotobuf[-lite] is too large; we're using nanopb instead. But we do want
# to test our serialization logic against libprotobuf.)
cc_library(
  firebase_firestore_protos_libprotobuf
  SOURCES
    cpp/firestore/local/maybe_document.pb.cc
    cpp/firestore/local/maybe_document.pb.h
    cpp/firestore/local/mutation.pb.cc
    cpp/firestore/local/mutation.pb.h
    cpp/firestore/local/target.pb.cc
    cpp/firestore/local/target.pb.h
    cpp/google/api/annotations.pb.cc
    cpp/google/api/annotations.pb.h
    cpp/google/api/http.pb.cc
    cpp/google/api/http.pb.h
    cpp/google/firestore/v1beta1/common.pb.cc
    cpp/google/firestore/v1beta1/common.pb.h
    cpp/google/firestore/v1beta1/document.pb.cc
    cpp/google/firestore/v1beta1/document.pb.h
    cpp/google/firestore/v1beta1/firestore.pb.cc
    cpp/google/firestore/v1beta1/firestore.pb.h
    cpp/google/firestore/v1beta1/query.pb.cc
    cpp/google/firestore/v1beta1/query.pb.h
    cpp/google/firestore/v1beta1/write.pb.cc
    cpp/google/firestore/v1beta1/write.pb.h
    cpp/google/rpc/status.pb.cc
    cpp/google/rpc/status.pb.h
    cpp/google/type/latlng.pb.cc
    cpp/google/type/latlng.pb.h
  DEPENDS
    protobuf::libprotobuf
  EXCLUDE_FROM_ALL
)

target_include_directories(
  firebase_firestore_protos_libprotobuf PUBLIC
  ${FIREBASE_SOURCE_DIR}/Firestore/Protos/cpp
)
