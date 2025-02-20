# Copyright 2017 Google LLC
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

set(CMAKE_CXX_EXTENSIONS ON)

# Required to allow 0 length printf style strings for testing purposes.
if(NOT MSVC)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-format-zero-length")
endif()


if(FIREBASE_IOS_BUILD_TESTS)
  firebase_ios_glob(
    sources *.cc *.h
    EXCLUDE *_benchmark.cc *_std_test.cc
  )

  if(APPLE)
    firebase_ios_glob(
      sources APPEND *.mm
      EXCLUDE *_benchmark.mm *_libdispatch_test.mm
    )
  endif()

  if(HAVE_LIBDISPATCH)
    firebase_ios_glob(sources APPEND *_libdispatch_test.mm)
  else()
    firebase_ios_glob(sources APPEND *_std_test.cc)
  endif()

  firebase_ios_add_test(firestore_util_test ${sources})

  target_link_libraries(
    firestore_util_test PRIVATE
    GMock::GMock
    absl_base
    absl_optional
    absl_strings
    firestore_core
    firestore_testutil
  )
endif()


# Benchmarks

if(FIREBASE_IOS_BUILD_BENCHMARKS)
  firebase_ios_add_executable(
    firestore_ordered_code_benchmark
    ordered_code_benchmark.cc
  )

  target_link_libraries(
    firestore_ordered_code_benchmark PRIVATE
    benchmark
    benchmark_main
    firestore_core
  )
endif()

if(FIREBASE_IOS_BUILD_BENCHMARKS AND APPLE)
  firebase_ios_add_executable(
    firestore_string_apple_benchmark
    string_apple_benchmark.mm
  )

  target_link_libraries(
    firestore_string_apple_benchmark PRIVATE
    benchmark
    benchmark_main
    firestore_core
  )
endif()
