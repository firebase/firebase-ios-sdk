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

# Generate output in-place. So long as the build is idempotent this helps
# verify that the protoc-generated output isn't changing.
set(OUTPUT_DIR ${CMAKE_CURRENT_SOURCE_DIR})

# Filename "roots" (i.e. without the .proto) from within the proto directory,
# excluding anything in google/protobuf.
set(
  PROTO_FILE_ROOTS
  firestore/local/maybe_document
  firestore/local/mutation
  firestore/local/target
  google/api/annotations
  google/api/http
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

# Converts a snake_case string to a CamelCase string.
#
# Input string must start and end with a lower case character, and must not
# have multiple consecutive underscores.
function(snake_case_to_camel_case str var)
  # prepend an underscore (to avoid special casing the first char)
  set(str "_${str}")
  while(TRUE)
    string(FIND ${str} "_" pos)
    if(${pos} EQUAL "-1")
      break()
    endif()
    MATH(EXPR pos "${pos}+1")
    string(SUBSTRING ${str} "${pos}" 1 lower_char)
    string(TOUPPER ${lower_char} upper_char)
    string(REPLACE  "_${lower_char}" ${upper_char} str ${str})
  endwhile()

  set(${var} ${str} PARENT_SCOPE)
endfunction()

# Populate PROTOBUF_OBJC_GENERATED_SOURCES with the list of libprotobuf
# Objective-C sources. These are used by the old Objective-C implementation
# that we're replacing.
#
# Libprotobuf Objective-C also includes the well-known protos so they must be
# omitted here.
set(
  PROTOBUF_OBJC_GENERATED_SOURCES
)
foreach(root ${PROTO_FILE_ROOTS})
  get_filename_component(dir ${root} DIRECTORY)
  get_filename_component(fname ${root} NAME)

  # protoc converts the filename from snake case to camel case, so we must do
  # that too.
  if(${fname} STREQUAL "http")
    # Hack: Something, somewhere is causing protoc to special case 'http' and
    # convert it to HTTP (rather than Http) for objc. So we'll special case it
    # here too.
    set(fname "HTTP")
  else()
    snake_case_to_camel_case(${fname} fname)
  endif()

  list(
    APPEND PROTOBUF_OBJC_GENERATED_SOURCES
    ${OUTPUT_DIR}/objc/${dir}/${fname}.pbobjc.h
    ${OUTPUT_DIR}/objc/${dir}/${fname}.pbobjc.m
  )
endforeach()


cc_library(
  firebase_firestore_protos_nanopb
  SOURCES
    ${NANOPB_GENERATED_SOURCES}
  DEPENDS
    firebase_firestore_nanopb
    protobuf-nanopb-static
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
    ${PROTOBUF_CPP_GENERATED_SOURCES}
  DEPENDS
    protobuf::libprotobuf
  EXCLUDE_FROM_ALL
)

target_include_directories(
  firebase_firestore_protos_libprotobuf PUBLIC
  ${FIREBASE_SOURCE_DIR}/Firestore/Protos/cpp
)

if(APPLE)
  cc_library(
    firebase_firestore_protos_objc
    SOURCES
      ${PROTOBUF_OBJC_GENERATED_SOURCES}
    DEPENDS
      libprotobuf_objc
    EXCLUDE_FROM_ALL
  )

  target_include_directories(
    firebase_firestore_protos_objc PRIVATE
    ${FIREBASE_SOURCE_DIR}/Firestore/Protos/objc/firestore/local
    ${FIREBASE_SOURCE_DIR}/Firestore/Protos/objc/google/firestore/v1
    ${FIREBASE_SOURCE_DIR}/Firestore/Protos/objc/google/api
    ${FIREBASE_SOURCE_DIR}/Firestore/Protos/objc/google/rpc
    ${FIREBASE_SOURCE_DIR}/Firestore/Protos/objc/google/type
  )
endif()


# Generate the python representation of descriptor.proto.
set(PROTOBUF_DIR ${FIREBASE_BINARY_DIR}/external/src/grpc/third_party/protobuf)
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

add_custom_command(
  COMMENT "Generating nanopb sources"
  OUTPUT ${NANOPB_GENERATED_SOURCES}
  COMMAND
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

add_custom_command(
  COMMENT "Generating C++ protobuf sources"
  OUTPUT ${PROTOBUF_CPP_GENERATED_SOURCES}
  COMMAND
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

add_custom_command(
  COMMENT "Generating Objective-C protobuf sources"
  OUTPUT ${PROTOBUF_OBJC_GENERATED_SOURCES}
  COMMAND
    ${CMAKE_CURRENT_SOURCE_DIR}/build_protos.py
      --objc
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
  generate_objc_protos
  DEPENDS
    ${PROTOBUF_OBJC_GENERATED_SOURCES}
)

# Custom target that runs a script to generate the proto sources. This isn't
# hooked into the build, so must be run manually. (It would be easy enough to
# hook into the (posix) cmake build, but for consistency with windows and xcode
# builds, we require this to be run manually with the results checked into
# source control.)
add_custom_target(
  generate_protos
  DEPENDS
    generate_nanopb_protos
    generate_cpp_protos
    generate_objc_protos
)

if(APPLE)
  set(
    protobuf_objc_source_dir
    ${FIREBASE_EXTERNAL_SOURCE_DIR}/grpc/third_party/protobuf/objectivec
  )
  objc_framework(
    Protobuf
    HEADERS
      ${protobuf_objc_source_dir}/GPBArray.h
      ${protobuf_objc_source_dir}/GPBArray_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBBootstrap.h
      ${protobuf_objc_source_dir}/GPBCodedInputStream.h
      ${protobuf_objc_source_dir}/GPBCodedInputStream_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBCodedOutputStream.h
      ${protobuf_objc_source_dir}/GPBCodedOutputStream_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBDescriptor.h
      ${protobuf_objc_source_dir}/GPBDescriptor_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBDictionary.h
      ${protobuf_objc_source_dir}/GPBDictionary_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBExtensionInternals.h
      ${protobuf_objc_source_dir}/GPBExtensionRegistry.h
      ${protobuf_objc_source_dir}/GPBMessage.h
      ${protobuf_objc_source_dir}/GPBMessage_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBProtocolBuffers.h
      ${protobuf_objc_source_dir}/GPBProtocolBuffers_RuntimeSupport.h
      ${protobuf_objc_source_dir}/GPBRootObject.h
      ${protobuf_objc_source_dir}/GPBRootObject_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBRuntimeTypes.h
      ${protobuf_objc_source_dir}/GPBUnknownField.h
      ${protobuf_objc_source_dir}/GPBUnknownFieldSet.h
      ${protobuf_objc_source_dir}/GPBUnknownFieldSet_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBUnknownField_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBUtilities.h
      ${protobuf_objc_source_dir}/GPBUtilities_PackagePrivate.h
      ${protobuf_objc_source_dir}/GPBWellKnownTypes.h
      ${protobuf_objc_source_dir}/GPBWireFormat.h
      ${protobuf_objc_source_dir}/google/protobuf/Any.pbobjc.h
      ${protobuf_objc_source_dir}/google/protobuf/Api.pbobjc.h
      ${protobuf_objc_source_dir}/google/protobuf/Duration.pbobjc.h
      ${protobuf_objc_source_dir}/google/protobuf/Empty.pbobjc.h
      ${protobuf_objc_source_dir}/google/protobuf/FieldMask.pbobjc.h
      ${protobuf_objc_source_dir}/google/protobuf/SourceContext.pbobjc.h
      ${protobuf_objc_source_dir}/google/protobuf/Struct.pbobjc.h
      ${protobuf_objc_source_dir}/google/protobuf/Timestamp.pbobjc.h
      ${protobuf_objc_source_dir}/google/protobuf/Type.pbobjc.h
      ${protobuf_objc_source_dir}/google/protobuf/Wrappers.pbobjc.h

    SOURCES
      ${protobuf_objc_source_dir}/GPBArray.m
      ${protobuf_objc_source_dir}/GPBCodedInputStream.m
      ${protobuf_objc_source_dir}/GPBCodedOutputStream.m
      ${protobuf_objc_source_dir}/GPBDescriptor.m
      ${protobuf_objc_source_dir}/GPBDictionary.m
      ${protobuf_objc_source_dir}/GPBExtensionInternals.m
      ${protobuf_objc_source_dir}/GPBExtensionRegistry.m
      ${protobuf_objc_source_dir}/GPBMessage.m
      ${protobuf_objc_source_dir}/GPBProtocolBuffers.m
      ${protobuf_objc_source_dir}/GPBRootObject.m
      ${protobuf_objc_source_dir}/GPBUnknownField.m
      ${protobuf_objc_source_dir}/GPBUnknownFieldSet.m
      ${protobuf_objc_source_dir}/GPBUtilities.m
      ${protobuf_objc_source_dir}/GPBWellKnownTypes.m
      ${protobuf_objc_source_dir}/GPBWireFormat.m
      ${protobuf_objc_source_dir}/google/protobuf/Any.pbobjc.m
      ${protobuf_objc_source_dir}/google/protobuf/Api.pbobjc.m
      ${protobuf_objc_source_dir}/google/protobuf/Duration.pbobjc.m
      ${protobuf_objc_source_dir}/google/protobuf/Empty.pbobjc.m
      ${protobuf_objc_source_dir}/google/protobuf/FieldMask.pbobjc.m
      ${protobuf_objc_source_dir}/google/protobuf/SourceContext.pbobjc.m
      ${protobuf_objc_source_dir}/google/protobuf/Struct.pbobjc.m
      ${protobuf_objc_source_dir}/google/protobuf/Timestamp.pbobjc.m
      ${protobuf_objc_source_dir}/google/protobuf/Type.pbobjc.m
      ${protobuf_objc_source_dir}/google/protobuf/Wrappers.pbobjc.m
  )
  target_include_directories(
    Protobuf
    PRIVATE
      ${protobuf_objc_source_dir}/google/protobuf
    INTERFACE
      ${PROJECT_BINARY_DIR}/Headers/Protobuf
    PUBLIC
      ${protobuf_objc_source_dir}
  )
  target_compile_options(
    Protobuf PRIVATE
    -fno-objc-arc
    -Wno-missing-noescape
  )
  add_alias(libprotobuf_objc Protobuf)

endif()
