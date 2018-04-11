cc_library(
  firebase_firestore_protos_nanopb
  SOURCES
    nanopb/firestore/local/maybe_document.pb.c
    nanopb/firestore/local/maybe_document.pb.h
    nanopb/firestore/local/mutation.pb.c
    nanopb/firestore/local/mutation.pb.h
    nanopb/firestore/local/target.pb.c
    nanopb/firestore/local/target.pb.h
    nanopb/google/api/annotations.pb.c
    nanopb/google/api/annotations.pb.h
    nanopb/google/api/http.pb.c
    nanopb/google/api/http.pb.h
    nanopb/google/firestore/v1beta1/common.pb.c
    nanopb/google/firestore/v1beta1/common.pb.h
    nanopb/google/firestore/v1beta1/document.pb.c
    nanopb/google/firestore/v1beta1/document.pb.h
    nanopb/google/firestore/v1beta1/firestore.pb.c
    nanopb/google/firestore/v1beta1/firestore.pb.h
    nanopb/google/firestore/v1beta1/query.pb.c
    nanopb/google/firestore/v1beta1/query.pb.h
    nanopb/google/firestore/v1beta1/write.pb.c
    nanopb/google/firestore/v1beta1/write.pb.h
    nanopb/google/protobuf/any.pb.c
    nanopb/google/protobuf/any.pb.h
    nanopb/google/protobuf/empty.pb.c
    nanopb/google/protobuf/empty.pb.h
    nanopb/google/protobuf/struct.pb.c
    nanopb/google/protobuf/struct.pb.h
    nanopb/google/protobuf/timestamp.pb.c
    nanopb/google/protobuf/timestamp.pb.h
    nanopb/google/protobuf/wrappers.pb.c
    nanopb/google/protobuf/wrappers.pb.h
    nanopb/google/rpc/status.pb.c
    nanopb/google/rpc/status.pb.h
    nanopb/google/type/latlng.pb.c
    nanopb/google/type/latlng.pb.h
  DEPENDS
    nanopb
)

target_compile_definitions(
  firebase_firestore_protos_nanopb PUBLIC
    -DPB_FIELD_16BIT
)

# TODO(rsgowman): this may be worth moving into cc_library, possibly via an
# INCLUDE_DIRS or similar.
target_include_directories(
  firebase_firestore_protos_nanopb PUBLIC
    ${FIREBASE_SOURCE_DIR}/Firestore/Protos/nanopb
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
    cpp/google/protobuf/any.pb.cc
    cpp/google/protobuf/any.pb.h
    cpp/google/protobuf/empty.pb.cc
    cpp/google/protobuf/empty.pb.h
    cpp/google/protobuf/struct.pb.cc
    cpp/google/protobuf/struct.pb.h
    cpp/google/protobuf/timestamp.pb.cc
    cpp/google/protobuf/timestamp.pb.h
    cpp/google/protobuf/wrappers.pb.cc
    cpp/google/protobuf/wrappers.pb.h
    cpp/google/rpc/status.pb.cc
    cpp/google/rpc/status.pb.h
    cpp/google/type/latlng.pb.cc
    cpp/google/type/latlng.pb.h
  DEPENDS
    protobuf
  EXCLUDE_FROM_ALL
)

target_include_directories(
  firebase_firestore_protos_libprotobuf PUBLIC
    ${FIREBASE_SOURCE_DIR}/Firestore/Protos/cpp
)

set_target_properties(
  firebase_firestore_protos_libprotobuf PROPERTIES
    COMPILE_FLAGS "-Wno-unused-parameter"
)
