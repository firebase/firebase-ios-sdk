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

if(NOT FUZZING)
  return()
endif()

# Finds the fuzzer library that is either provided by OSS Fuzz, if enabled, or
# libFuzzer that is manually built from sources.
find_package(Fuzzer REQUIRED)

cc_binary(
  serializer_fuzzer
  SOURCES
    serializer_fuzzer.cc
  DEPENDS
    Fuzzer
    firebase_firestore_remote
)

# Copy the serializer dictionary and corpus from the FuzzingResources in iOS
# fuzz tests.
# TODO(minafarid): Generate the serializer corpus by converting the text protos
# from the serializer corpus in the iOS FuzzintResources to binary protos. This
# conversion requires the protoc binary that is not currently available.
set(serializer_resources ${FIREBASE_SOURCE_DIR}/Firestore/Example/FuzzTests/FuzzingResources/Serializer)
add_custom_command(
  TARGET serializer_fuzzer POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy
    ${serializer_resources}/serializer.dictionary serializer_fuzzer.dict
  COMMAND ${CMAKE_COMMAND} -E copy_directory
    ${serializer_resources}/Corpus/BinaryProtos serializer_fuzzer_seed_corpus
)
