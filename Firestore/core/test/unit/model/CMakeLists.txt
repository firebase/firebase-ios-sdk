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

firebase_ios_glob(
  sources *.cc *.h
)

if(FIREBASE_IOS_BUILD_TESTS)
  firebase_ios_add_test(firestore_model_test ${sources})

  target_link_libraries(
    firestore_model_test PRIVATE
    GMock::GMock
    firestore_core
    firestore_testutil
  )
endif()

if(FIREBASE_IOS_BUILD_BENCHMARKS)
  firebase_ios_add_executable(
    firestore_field_value_benchmark
    field_value_benchmark.cc
  )

  target_link_libraries(
    firestore_field_value_benchmark PRIVATE
    absl::variant
    benchmark
    benchmark_main
    firestore_core
    firestore_testutil
  )
endif()
