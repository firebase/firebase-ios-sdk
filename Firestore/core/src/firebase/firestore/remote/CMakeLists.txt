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

# `roots.pem` is a file containing root certificates that is distributed
# alongside gRPC and is necessary to establish SSL connections. Embed this file
# into the binary by converting it to a char array.
add_custom_command(
    OUTPUT grpc_root_certificates_generated.h grpc_root_certificates_generated.cc
    COMMAND python ${FIREBASE_SOURCE_DIR}/scripts/binary_to_array.py
        --output_header=grpc_root_certificates_generated.h
        --output_source=grpc_root_certificates_generated.cc
        --cpp_namespace=firebase::firestore::remote
        --array=grpc_root_certificates_generated_data
        --array_size=grpc_root_certificates_generated_size
        ${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/etc/roots.pem
    DEPENDS
    ${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/etc/roots.pem
)

cc_library(
  firebase_firestore_remote
  SOURCES
    exponential_backoff.cc
    exponential_backoff.h
    grpc_call.h
    grpc_completion.cc
    grpc_completion.h
    grpc_connection.cc
    grpc_connection.h
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
    remote_event.cc
    remote_event.h
    serializer.cc
    serializer.h
    watch_change.h
    watch_change.mm

    # TODO(varconst): add these files once they no longer depend on Objective-C
    # serializer.
    # datastore.h
    # datastore.mm
    # remote_objc_bridge.h
    # remote_objc_bridge.mm
    # stream.h
    # stream.mm
    # watch_stream.h
    # watch_stream.mm
    # write_stream.h
    # write_stream.mm

  DEPENDS
    # TODO(b/111328563) Force nanopb first to work around ODR violations
    protobuf-nanopb-static

    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_remote_connectivity_monitor
    firebase_firestore_util
    firebase_firestore_version

    grpc++
)
