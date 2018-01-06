# Copyright 2017 Google
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

# firebase_firestore_util is the interface of this module. The rest of the
# libraries in here are an implementation detail of making this a
# mutli-platform build.

add_library(
  firebase_firestore_util_base
  secure_random_arc4random.cc
  string_printf.cc
)
target_link_libraries(
  firebase_firestore_util_base
  PRIVATE
  absl_base
)

# stdio-dependent bits can be built and tested everywhere
add_library(
  firebase_firestore_util_stdio
  log_stdio.cc
)
target_link_libraries(
  firebase_firestore_util_stdio
  PUBLIC
  firebase_firestore_util_base
)

# apple-dependent bits can only built and tested on apple plaforms
if(APPLE)
  add_library(
    firebase_firestore_util_apple
    log_apple.mm
  )
  target_compile_options(
    firebase_firestore_util_apple
    PRIVATE
    ${OBJC_FLAGS}
  )
  target_link_libraries(
    firebase_firestore_util_apple
    PUBLIC
    FirebaseCore
  )
endif(APPLE)

add_library(
  firebase_firestore_util
  autoid.cc
)

# Export a dependency on the correct logging library for this platform. All
# buildable libraries are built and tested but only the best fit is exported.
if(APPLE)
  target_link_libraries(
    firebase_firestore_util
    PUBLIC
    firebase_firestore_util_apple
    firebase_firestore_util_base
  )

else(NOT APPLE)
  target_link_libraries(
    firebase_firestore_util
    PUBLIC
    firebase_firestore_util_stdio
    firebase_firestore_util_base
  )

endif(APPLE)
