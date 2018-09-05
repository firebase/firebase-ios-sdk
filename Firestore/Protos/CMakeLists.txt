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
    nanopb/firestore/local/maybe_document.nanopb.c
    nanopb/firestore/local/maybe_document.nanopb.h
    nanopb/firestore/local/mutation.nanopb.c
    nanopb/firestore/local/mutation.nanopb.h
    nanopb/firestore/local/target.nanopb.c
    nanopb/firestore/local/target.nanopb.h
    nanopb/google/api/annotations.nanopb.c
    nanopb/google/api/annotations.nanopb.h
    nanopb/google/api/http.nanopb.c
    nanopb/google/api/http.nanopb.h
    nanopb/google/firestore/v1beta1/common.nanopb.c
    nanopb/google/firestore/v1beta1/common.nanopb.h
    nanopb/google/firestore/v1beta1/document.nanopb.c
    nanopb/google/firestore/v1beta1/document.nanopb.h
    nanopb/google/firestore/v1beta1/firestore.nanopb.c
    nanopb/google/firestore/v1beta1/firestore.nanopb.h
    nanopb/google/firestore/v1beta1/query.nanopb.c
    nanopb/google/firestore/v1beta1/query.nanopb.h
    nanopb/google/firestore/v1beta1/write.nanopb.c
    nanopb/google/firestore/v1beta1/write.nanopb.h
    nanopb/google/protobuf/any.nanopb.c
    nanopb/google/protobuf/any.nanopb.h
    nanopb/google/protobuf/empty.nanopb.c
    nanopb/google/protobuf/empty.nanopb.h
    nanopb/google/protobuf/struct.nanopb.c
    nanopb/google/protobuf/struct.nanopb.h
    nanopb/google/protobuf/timestamp.nanopb.c
    nanopb/google/protobuf/timestamp.nanopb.h
    nanopb/google/protobuf/wrappers.nanopb.c
    nanopb/google/protobuf/wrappers.nanopb.h
    nanopb/google/rpc/status.nanopb.c
    nanopb/google/rpc/status.nanopb.h
    nanopb/google/type/latlng.nanopb.c
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


set(PROTOBUF_DIR ${FIREBASE_BINARY_DIR}/external/src/grpc/third_party/protobuf)
set(NANOPB_DIR ${FIREBASE_BINARY_DIR}/external/src/nanopb)
#set(OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated_protos)
set(NANOPB_OUTPUT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

set(
  PROTOBUF_PROTO
  ${PROTOBUF_DIR}/src/google/protobuf/descriptor.proto
  ${NANOPB_DIR}/generator/proto/nanopb.proto
  ${NANOPB_DIR}/generator/proto/plugin.proto
)

set(
  PROTOBUF_PYTHON
  ${PROTOBUF_DIR}/python/google/protobuf/descriptor_pb2.py
  ${PROTOBUF_DIR}/python/proto/nanopb_pb2.py
  ${PROTOBUF_DIR}/python/proto/plugin_pb2.py
)

set(
  PROTO_INCLUDES
  -I${CMAKE_CURRENT_SOURCE_DIR}/protos
  -I${NANOPB_DIR}/generator
  -I${PROTOBUF_DIR}/src
)

add_custom_command(
  COMMENT "Generating protoc python plugins"
  OUTPUT
    ${PROTOBUF_PYTHON}
  COMMAND
    $<TARGET_FILE:protoc>
      ${PROTO_INCLUDES}
      --python_out=${PROTOBUF_DIR}/python
      ${PROTOBUF_PROTO}
  VERBATIM
  DEPENDS
    protoc
    ${PROTOBUF_PROTO}
)

add_custom_target(
  generate_nanopb_protos
  COMMENT "Generatoring nanopb sources"
  COMMAND
    ${CMAKE_CURRENT_SOURCE_DIR}/build_protos.py
      --nanopb
      --protoc=$<TARGET_FILE:protoc>
      --protoc-gen-nanopb=${NANOPB_DIR}/generator/protoc-gen-nanopb
      --pythonpath=${PROTOBUF_DIR}/python
      --output-dir=${OUTPUT_DIR}
      ${PROTO_INCLUDES}
  VERBATIM
  DEPENDS
    protoc
    ${CMAKE_CURRENT_SOURCE_DIR}/build_protos.py
    ${PROTOBUF_PYTHON}
)

# Custom target that runs a script to generate the proto sources. This isn't
# hooked into the build, so must be run manually. (It would be easy enough to
# hook into the (posix) cmake build, but for consistency with windows and xcode
# builds, we require this to be run manually with the results checked into
# source control.)
add_custom_target(
  generate_protos
  COMMENT "Generating proto sources"
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  VERBATIM

  COMMAND
    cmake -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/generated_protos
    mkdir -p "${CMAKE_CURRENT_BINARY_DIR}/generated_protos"
  COMMAND
    ./build-protos.sh
      "$<TARGET_FILE:protoc>"
      "$<TARGET_FILE:grpc_objective_c_plugin>"
      "${FIREBASE_BINARY_DIR}/external/src/grpc/third_party/protobuf/python"
      "${NANOPB_DIR}/generator"
      "${CMAKE_CURRENT_BINARY_DIR}/generated_protos"

  DEPENDS
    protoc
    grpc_objective_c_plugin
    ${PROTOBUF_PYTHON}
)
