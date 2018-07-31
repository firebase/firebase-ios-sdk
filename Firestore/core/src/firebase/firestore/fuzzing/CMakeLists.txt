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

if(NOT FUZZING AND NOT OSS_FUZZ)
  return()
endif()

# Finds the fuzzing library that is either provided by OSS Fuzz, if enabled, or
# libFuzzer that is manually built from sources.
find_package(FuzzingLibrary REQUIRED)

cc_binary(
  firebase_firestore_fuzzing_serializer
  SOURCES
    fuzz_test_serializer.cc
  DEPENDS
    FuzzingLibrary
    firebase_firestore_remote
)
