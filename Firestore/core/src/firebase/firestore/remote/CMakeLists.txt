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
    "-framework SystemConfiguration"
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

# Source files should be generated in place so that the XCode build can pick
# them up.
set(OUTPUT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

list(
  APPEND GRPC_ROOT_CERTIFICATE_SOURCES
  ${OUTPUT_DIR}/grpc_root_certificates_generated.h  # NOLINT(generated)
  ${OUTPUT_DIR}/grpc_root_certificates_generated.cc # NOLINT(generated)
)

# `roots.pem` is a file containing root certificates that is distributed
# alongside gRPC and is necessary to establish SSL connections. Embed this file
# into the binary by converting it to a char array.
add_custom_command(
  COMMENT "Generating root certificates for embedding"
  OUTPUT
    ${GRPC_ROOT_CERTIFICATE_SOURCES}
  COMMAND python ${FIREBASE_SOURCE_DIR}/scripts/binary_to_array.py
      --output_header=grpc_root_certificates_generated.h
      --output_source=grpc_root_certificates_generated.cc
      --logical_directory=Firestore/core/src/firebase/firestore/remote
      --physical_directory=${OUTPUT_DIR}
      --cpp_namespace=firebase::firestore::remote
      --array=grpc_root_certificates_generated_data
      --array_size=grpc_root_certificates_generated_size
      ${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/etc/roots.pem
  VERBATIM
  DEPENDS
    grpc
    ${FIREBASE_SOURCE_DIR}/scripts/binary_to_array.py
    ${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/etc/roots.pem
)

# gRPC certificates have to be regenerated manually on each new gRPC release
# (which typically has updated certificates).
add_custom_target(
  generate_grpc_root_certificates
  DEPENDS
    ${GRPC_ROOT_CERTIFICATE_SOURCES}
)

cc_library(
  firebase_firestore_remote
  SOURCES
    datastore.cc
    datastore.h
    existence_filter.h
    exponential_backoff.cc
    exponential_backoff.h
    grpc_call.h
    grpc_completion.cc
    grpc_completion.h
    grpc_connection.cc
    grpc_connection.h
    grpc_nanopb.cc
    grpc_nanopb.h
    grpc_root_certificate_finder.h
    grpc_root_certificate_finder_generated.cc
    grpc_root_certificates_generated.cc
    grpc_root_certificates_generated.h
    grpc_stream.cc
    grpc_stream.h
    grpc_stream_observer.h
    grpc_streaming_reader.cc
    grpc_streaming_reader.h
    grpc_unary_call.cc
    grpc_unary_call.h
    grpc_util.cc
    grpc_util.cc
    grpc_util.h
    online_state_tracker.cc
    online_state_tracker.h
    remote_event.cc
    remote_event.h
    remote_objc_bridge.cc
    remote_objc_bridge.h
    remote_store.cc
    remote_store.h
    serializer.cc
    serializer.h
    stream.cc
    stream.h
    watch_change.cc
    watch_change.h
    watch_stream.cc
    watch_stream.h
    write_stream.cc
    write_stream.h

  DEPENDS
    firebase_firestore_core
    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_remote_connectivity_monitor
    firebase_firestore_util
    firebase_firestore_version
    grpc++
    protobuf-nanopb-static
)
