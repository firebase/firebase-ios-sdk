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

add_library(
  firebase_firestore_util
  autoid.cc
  secure_random_arc4random.cc
)

# log_stdio can be built and tested everywhere
add_library(
  firebase_firestore_util_log_stdio
  log_stdio.cc
)

# log_apple can only built and tested on apple plaforms
if(APPLE)
  add_library(
    firebase_firestore_util_log_apple
    log_apple.mm
  )
  target_compile_options(
    firebase_firestore_util_log_apple
    PRIVATE
    ${OBJC_FLAGS}
  )
  target_link_libraries(
    firebase_firestore_util_log_apple
    PUBLIC
    FirebaseCore
  )
endif(APPLE)

# Export a dependency on the correct logging library for this platform. All
# buildable libraries are built and tested but only the best fit is exported.
if(APPLE)
  target_link_libraries(
    firebase_firestore_util
    PUBLIC
    firebase_firestore_util_log_apple
  )

else(NOT APPLE)
  target_link_libraries(
    firebase_firestore_util
    PUBLIC
    firebase_firestore_util_log_stdio
  )

endif(APPLE)
