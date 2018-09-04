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

set(NANOPB_GENERATOR_DIR ${FIREBASE_BINARY_DIR}/external/src/nanopb/generator)

set(PROTOBUF_DIR ${FIREBASE_BINARY_DIR}/external/src/grpc/third_party/protobuf)
set(DESCRIPTOR_PROTO_SRC
  ${PROTOBUF_DIR}/src/google/protobuf/descriptor.proto
)
set(DESCRIPTOR_PYTHON_SRC
  ${PROTOBUF_DIR}/python/google/protobuf/descriptor_pb2.py
)
add_custom_command(
  OUTPUT ${DESCRIPTOR_PYTHON_SRC}
  COMMAND
    protoc
      -I${PROTOBUF_DIR}/src
      --python_out=${PROTOBUF_DIR}/python
      ${DESCRIPTOR_PROTO_SRC}
  DEPENDS
    protoc
    ${DESCRIPTOR_PROTO_SRC}
)

# Build nanopb protoc plugin. (Heavily "inspired" by
# https://github.com/nanopb/nanopb/blob/master/extra/FindNanopb.cmake)
set(NANOPB_GENERATOR_BASENAMES nanopb plugin)
set(NANOPB_GENERATOR_PYTHON_SRC ${DESCRIPTOR_PYTHON_SRC})
foreach (GENERATOR_BASENAME ${NANOPB_GENERATOR_BASENAMES})
  set(input "${NANOPB_GENERATOR_DIR}/proto/${GENERATOR_BASENAME}.proto")
  set(output "${NANOPB_GENERATOR_DIR}/proto/${GENERATOR_BASENAME}_pb2.py")
  set(NANOPB_GENERATOR_PYTHON_SRC ${NANOPB_GENERATOR_PYTHON_SRC} ${output})
  add_custom_command(
    OUTPUT ${output}
    COMMAND
      protoc
        -I${NANOPB_GENERATOR_DIR}/proto
        --python_out=${NANOPB_GENERATOR_DIR}/proto
        ${input}
    DEPENDS
      protoc
      ${input}
  )
endforeach()

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
    mkdir -p "${CMAKE_CURRENT_BINARY_DIR}/generated_protos"
  COMMAND
    ./build-protos.sh
      "$<TARGET_FILE:protoc>"
      "$<TARGET_FILE:grpc_objective_c_plugin>"
      "${FIREBASE_BINARY_DIR}/external/src/grpc/third_party/protobuf/python"
      "${NANOPB_GENERATOR_DIR}"
      "${CMAKE_CURRENT_BINARY_DIR}/generated_protos"

  DEPENDS
    protoc
    ${NANOPB_GENERATOR_PYTHON_SRC}
    grpc_objective_c_plugin
)
