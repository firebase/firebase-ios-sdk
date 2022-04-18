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

include(FindPythonInterp)

# Generate output in-place. So long as the build is idempotent this helps
# verify that the protoc-generated output isn't changing.
set(OUTPUT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

# Generating protobuf and nanopb sources when cross compiling doesn't work
# because CMake can't build protoc for the host when building cross targets.
#
# On Windows, this *could* work, but it's not worth the time to figure out why
# because the generated sources are already checked in.
set(FIREBASE_IOS_PROTOC_GENERATE_SOURCES ON)
if(WIN32 OR IOS OR ANDROID OR CMAKE_CROSSCOMPILING)
  set(FIREBASE_IOS_PROTOC_GENERATE_SOURCES OFF)
endif()

# Filename "roots" (i.e. without the .proto) from within the proto directory,
# excluding anything in google/protobuf.
set(
  PROTO_FILE_ROOTS
  firestore/local/maybe_document
  firestore/local/mutation
  firestore/local/target
  firestore/bundle
  google/api/annotations
  google/api/http
  google/firestore/admin/index
  google/firestore/v1/common
  google/firestore/v1/document
  google/firestore/v1/firestore
  google/firestore/v1/query
  google/firestore/v1/write
  google/rpc/status
  google/type/latlng
)

# Full filenames (i.e. with the .proto) from within the proto directory,
# excluding anything in google/protobuf
foreach(root ${PROTO_FILE_ROOTS})
  list(
    APPEND PROTO_FILES
    ${OUTPUT_DIR}/protos/${root}.proto
  )
  if(EXISTS ${OUTPUT_DIR}/protos/${root}.options)
    list(
      APPEND PROTO_FILES_OPTIONS
      ${OUTPUT_DIR}/protos/${root}.options
    )
  endif()
endforeach()

# Filename "roots" (i.e. without the .proto) from within the proto directory,
# from the google/protobuf package.
set(
  WELL_KNOWN_PROTO_FILE_ROOTS
  google/protobuf/any
  google/protobuf/empty
  google/protobuf/struct
  google/protobuf/timestamp
  google/protobuf/wrappers
)

# Full filenames (i.e. with the .proto) from within the proto directory, from
# the google/protobuf package.
foreach(root ${WELL_KNOWN_PROTO_FILE_ROOTS})
  list(
    APPEND WELL_KNOWN_PROTO_FILES
    ${OUTPUT_DIR}/protos/${root}.proto
  )
endforeach()

# Populate NANOPB_GENERATED_SOURCES with the list of nanopb-generated sources.
# The nanopb runtime does not include the well-known protos so we have to build
# them ourselves.
foreach(root ${PROTO_FILE_ROOTS} ${WELL_KNOWN_PROTO_FILE_ROOTS})
  list(
    APPEND NANOPB_GENERATED_SOURCES
    ${OUTPUT_DIR}/nanopb/${root}.nanopb.cc
    ${OUTPUT_DIR}/nanopb/${root}.nanopb.h
  )
endforeach()

# Populate PROTOBUF_CPP_GENERATED_SOURCES with the list of libprotobuf C++
# sources. These are used for verifying interoperation from nanopb.
#
# Libprotobuf includes the well-known protos so they must be omitted here.
foreach(root ${PROTO_FILE_ROOTS})
  list(
    APPEND PROTOBUF_CPP_GENERATED_SOURCES
    ${OUTPUT_DIR}/cpp/${root}.pb.cc
    ${OUTPUT_DIR}/cpp/${root}.pb.h
  )
endforeach()

firebase_ios_add_library(
  firestore_protos_nanopb DISABLE_STRICT_WARNINGS EXCLUDE_FROM_ALL
  ${NANOPB_GENERATED_SOURCES}
)

target_include_directories(
  firestore_protos_nanopb PUBLIC
  ${CMAKE_CURRENT_LIST_DIR}/nanopb
)

target_link_libraries(
  firestore_protos_nanopb PUBLIC
  firestore_nanopb
  protobuf-nanopb-static
  absl_strings
)

# libprotobuf based generated protos. Expected only to be used in test (as
# libprotobuf[-lite] is too large; we're using nanopb instead. But we do want
# to test our serialization logic against libprotobuf.)
firebase_ios_add_library(
  firestore_protos_protobuf DISABLE_STRICT_WARNINGS EXCLUDE_FROM_ALL
  ${PROTOBUF_CPP_GENERATED_SOURCES}
)

target_include_directories(
  firestore_protos_protobuf PUBLIC
  ${CMAKE_CURRENT_LIST_DIR}/cpp
)

target_link_libraries(
  firestore_protos_protobuf PUBLIC
  protobuf::libprotobuf
)

# Generate the python representation of descriptor.proto.
set(PROTOBUF_DIR ${FIREBASE_EXTERNAL_SOURCE_DIR}/protobuf)
set(PROTOBUF_PROTO ${PROTOBUF_DIR}/src/google/protobuf/descriptor.proto)
set(PROTOBUF_PYTHON ${PROTOBUF_DIR}/python/google/protobuf/descriptor_pb2.py)

add_custom_command(
  COMMENT "Generating protoc python plugins"
  OUTPUT ${PROTOBUF_PYTHON}
  COMMAND
    protoc
      -I${PROTOBUF_DIR}/src
      --python_out=${PROTOBUF_DIR}/python
      ${PROTOBUF_PROTO}
  VERBATIM
  DEPENDS
    protoc
    ${PROTOBUF_PROTO}
)

# Generate the python representation of nanopb's protos
set(NANOPB_DIR ${FIREBASE_BINARY_DIR}/external/src/nanopb)
set(
  NANOPB_PROTO
  ${NANOPB_DIR}/generator/proto/nanopb.proto
  ${NANOPB_DIR}/generator/proto/plugin.proto
)
set(
  NANOPB_PYTHON
  ${NANOPB_DIR}/generator/proto/nanopb_pb2.py
  ${NANOPB_DIR}/generator/proto/plugin_pb2.py
)

set(
  PROTO_INCLUDES
  -I${CMAKE_CURRENT_SOURCE_DIR}/protos
  -I${NANOPB_DIR}/generator
  -I${PROTOBUF_DIR}/src
)

add_custom_command(
  COMMENT "Generating nanopb python plugins"
  OUTPUT ${NANOPB_PYTHON}
  COMMAND
    protoc
      -I${NANOPB_DIR}/generator
      -I${PROTOBUF_DIR}/src
      --python_out=${NANOPB_DIR}/generator
      ${NANOPB_PROTO}
  VERBATIM
  DEPENDS
    protoc
    ${NANOPB_PROTO}
)

if(FIREBASE_IOS_PROTOC_GENERATE_SOURCES)
  add_custom_command(
    COMMENT "Generating nanopb sources"
    OUTPUT ${NANOPB_GENERATED_SOURCES}
    COMMAND
      ${PYTHON_EXECUTABLE}
        ${CMAKE_CURRENT_SOURCE_DIR}/build_protos.py
        --nanopb
        --protoc=$<TARGET_FILE:protoc>
        --pythonpath=${PROTOBUF_DIR}/python:${NANOPB_DIR}/generator
        --output_dir=${OUTPUT_DIR}
        ${PROTO_INCLUDES}
    VERBATIM
    DEPENDS
      protoc
      ${CMAKE_CURRENT_SOURCE_DIR}/build_protos.py
      ${CMAKE_CURRENT_SOURCE_DIR}/nanopb_cpp_generator.py
      ${CMAKE_CURRENT_SOURCE_DIR}/lib/pretty_printing.py
      ${NANOPB_PYTHON}
      ${PROTOBUF_PYTHON}
      ${PROTO_FILES}
      ${PROTO_FILES_OPTIONS}
      ${WELL_KNOWN_PROTO_FILES}
  )

  add_custom_target(
    generate_nanopb_protos
    DEPENDS
      ${NANOPB_GENERATED_SOURCES}
  )
endif()

if(FIREBASE_IOS_PROTOC_GENERATE_SOURCES)
  add_custom_command(
    COMMENT "Generating C++ protobuf sources"
    OUTPUT ${PROTOBUF_CPP_GENERATED_SOURCES}
    COMMAND
      ${PYTHON_EXECUTABLE}
        ${CMAKE_CURRENT_SOURCE_DIR}/build_protos.py
        --cpp
        --protoc=$<TARGET_FILE:protoc>
        --output_dir=${OUTPUT_DIR}
        ${PROTO_INCLUDES}
    VERBATIM
    DEPENDS
      protoc
      ${CMAKE_CURRENT_SOURCE_DIR}/build_protos.py
      ${PROTO_FILES}
  )

  add_custom_target(
    generate_cpp_protos
    DEPENDS
      ${PROTOBUF_CPP_GENERATED_SOURCES}
  )
endif()

# Custom target that runs a script to generate the proto sources. This isn't
# hooked into the build, so must be run manually. (It would be easy enough to
# hook into the (posix) cmake build, but for consistency with windows and xcode
# builds, we require this to be run manually with the results checked into
# source control.)
if(FIREBASE_IOS_PROTOC_GENERATE_SOURCES)
  add_custom_target(
    generate_protos
    DEPENDS
    generate_nanopb_protos
    generate_cpp_protos
  )
endif()
