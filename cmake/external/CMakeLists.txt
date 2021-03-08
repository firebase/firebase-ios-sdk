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

cmake_minimum_required(VERSION 3.5.1)
project(Firebase-download C CXX)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR})

set(
  FIREBASE_DOWNLOAD_DIR
  ${PROJECT_BINARY_DIR}/downloads
  CACHE PATH "Where to store downloaded files"
)

include(abseil-cpp)
include(benchmark)
include(boringssl)
include(c-ares)
include(googletest)
include(GoogleUtilities)
include(grpc)
include(leveldb)
include(libfuzzer)
include(nanopb)
include(protobuf)
include(zlib)
