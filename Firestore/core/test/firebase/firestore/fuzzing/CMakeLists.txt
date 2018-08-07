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

# Builds all fuzzing targets and copies/generates a dictionary and a corpus for
# each target. A fuzzing target that tests xyz must be called 'xyz_fuzzer' and
# its dictionary 'xyz_fuzzer.dict' and its corpus 'xyz_fuzzer_seed_corpus'.
# This naming convention is required for our OSS Fuzz build script to capture
# new fuzzing targets.

if(NOT FUZZING)
  return()
endif()

# Finds the fuzzer library that is either provided by OSS Fuzz, if enabled, or
# libFuzzer that is manually built from sources.
find_package(Fuzzer REQUIRED)

# Use the fuzzing resources directory from the iOS fuzz tests.
set(fuzzing_resources ${FIREBASE_SOURCE_DIR}/Firestore/Example/FuzzTests/FuzzingResources)

# Serializer fuzzing target.
cc_binary(
  serializer_fuzzer
  SOURCES
    serializer_fuzzer.cc
  DEPENDS
    Fuzzer
    firebase_firestore_remote
)

# Copy serializer dictionary and corpus.
# TODO(minafarid): Generate the serializer corpus by converting the text protos
# from the serializer corpus in the iOS FuzzingResources to binary protos. This
# conversion requires the protoc binary that is not currently available.
add_custom_command(
  TARGET serializer_fuzzer POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy
      ${fuzzing_resources}/Serializer/serializer.dictionary serializer_fuzzer.dict
  COMMAND ${CMAKE_COMMAND} -E copy_directory
      ${fuzzing_resources}/Serializer/Corpus/BinaryProtos serializer_fuzzer_seed_corpus
)

# FieldPath fuzzing target.
cc_binary(
  fieldpath_fuzzer
  SOURCES
    fieldpath_fuzzer.cc
  DEPENDS
    Fuzzer
    firebase_firestore_model
)

# Copy dictionary and corpus.
add_custom_command(
  TARGET fieldpath_fuzzer
  COMMAND ${CMAKE_COMMAND} -E copy
      ${fuzzing_resources}/FieldPath/fieldpath.dictionary fieldpath_fuzzer.dict
  COMMAND ${CMAKE_COMMAND} -E copy_directory
      ${fuzzing_resources}/FieldPath/Corpus fieldpath_fuzzer_seed_corpus
)
