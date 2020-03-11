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

# Builds all fuzzing targets using firebase_ios_cc_fuzz_test build rule, which
# copies the provided dictionary and corpus to the destination directory. A
# fuzzing target that tests xyz must be called 'xyz_fuzzer'. The copied
# dictionary will be called 'xyz_fuzzer.dict' and its corpus
# 'xyz_fuzzer_seed_corpus'. See cc_rules.cmake for more information.

if(NOT FUZZING)
  return()
endif()

# Use the fuzzing resources directory from the iOS fuzz tests.
set(fuzzing_resources ${FIREBASE_SOURCE_DIR}/Firestore/Example/FuzzTests/FuzzingResources)

# Serializer fuzzing target.
# TODO(minafarid): Do not define a CORPUS in this target, but rather generate
# the serializer corpus by converting the text protos from the serializer
# corpus in the iOS FuzzingResources to binary protos. This conversion requires
# the protoc binary that is not currently available.
firebase_ios_cc_fuzz_test(
  serializer_fuzzer
  DICTIONARY ${fuzzing_resources}/Serializer/serializer.dictionary
  CORPUS     ${fuzzing_resources}/Serializer/Corpus/BinaryProtos
  SOURCES    serializer_fuzzer.cc
  DEPENDS    firebase_firestore_remote
)


# FieldPath fuzzing target.
firebase_ios_cc_fuzz_test(
  fieldpath_fuzzer
  DICTIONARY ${fuzzing_resources}/FieldPath/fieldpath.dictionary
  CORPUS     ${fuzzing_resources}/FieldPath/Corpus
  SOURCES    fieldpath_fuzzer.cc
  DEPENDS    firebase_firestore_model
)

# ResourcePath fuzzing target. Use the same corpus and dict as FieldPath.
firebase_ios_cc_fuzz_test(
  resourcepath_fuzzer
  DICTIONARY ${fuzzing_resources}/FieldPath/fieldpath.dictionary
  CORPUS     ${fuzzing_resources}/FieldPath/Corpus
  SOURCES    resourcepath_fuzzer.cc
  DEPENDS    firebase_firestore_model
)

# LevelDB fuzzer.
firebase_ios_cc_fuzz_test(
  leveldb_fuzzer
  DICTIONARY ${fuzzing_resources}/LevelDb/leveldb.dictionary
  SOURCES leveldb_fuzzer.cc
  DEPENDS firebase_firestore_local_persistence_leveldb
)
