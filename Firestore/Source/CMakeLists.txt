# Copyright 2019 Google LLC
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

if(NOT APPLE)
  return()
endif()

if(NOT FIRESTORE_INCLUDE_OBJC)
  return()
endif()

file(GLOB headers Public/FirebaseFirestore/*.h)
file(GLOB sources API/*.h API/*.m API/*.mm)

firebase_ios_add_framework(FirebaseFirestore ${headers} ${sources})
firebase_ios_framework_public_headers(FirebaseFirestore ${headers})

target_link_libraries(
  FirebaseFirestore PUBLIC
  FirebaseAppCheckInterop
  FirebaseAuthInterop
  FirebaseCore
  absl_strings
  firestore_core
)
