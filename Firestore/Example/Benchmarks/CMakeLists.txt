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

if(NOT FIREBASE_IOS_BUILD_BENCHMARKS OR NOT APPLE)
  return()
endif()

firebase_ios_add_executable(
  firestore_remote_document_cache_benchmark
  remote_document_cache_benchmark.mm
)

target_link_libraries(
  firestore_remote_document_cache_benchmark PRIVATE
  FirebaseFirestore
  benchmark
  benchmark_main
  firestore_testutil
)
