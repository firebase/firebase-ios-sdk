# Copyright 2021 Google LLC
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

file(GLOB headers Public/FirebaseAppCheckInterop/*.h)
firebase_ios_generate_dummy_source(FirebaseAppCheckInterop sources)

firebase_ios_add_framework(
  FirebaseAppCheckInterop DISABLE_STRICT_WARNINGS EXCLUDE_FROM_ALL
  ${headers} ${sources}
)

firebase_ios_framework_public_headers(FirebaseAppCheckInterop ${headers})
