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
    exponential_backoff.h
    exponential_backoff.cc
    grpc_call.h
    grpc_completion.h
    grpc_completion.cc
    grpc_connection.h
    grpc_connection.cc
    grpc_stream.h
    grpc_stream.cc
    grpc_stream_observer.h
    grpc_streaming_reader.h
    grpc_streaming_reader.cc
    grpc_unary_call.h
    grpc_unary_call.cc
    grpc_util.h
    grpc_util.cc
    grpc_util.cc
    serializer.h
    serializer.cc

    # TODO(varconst): add these files once they're no longer dependent on
    # Objective-C.
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

    grpc_root_certificate_finder.h
    grpc_root_certificate_finder_filesystem.cc
    ${external_src_dir}/grpc/etc/roots.pem

  DEPENDS
    # TODO(b/111328563) Force nanopb first to work around ODR violations
    protobuf-nanopb

    firebase_firestore_version

    firebase_firestore_model
    firebase_firestore_nanopb
    firebase_firestore_protos_nanopb
    firebase_firestore_remote_connectivity_monitor
    firebase_firestore_util
  EXTERNAL_DEPENDS
    grpc++
  RESOURCES
    ${external_src_dir}/grpc/etc/roots.pem
)
# This line works
# configure_file(${external_src_dir}/grpc/etc/roots.pem ${FIREBASE_BINARY_DIR} COPYONLY)
