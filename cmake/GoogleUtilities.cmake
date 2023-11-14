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

# Environment and Logger subspecs
file(
  GLOB sources
  ${FIREBASE_EXTERNAL_SOURCE_DIR}/GoogleUtilities/GoogleUtilities/Environment/*.m
  ${FIREBASE_EXTERNAL_SOURCE_DIR}/GoogleUtilities/third_party/IsAppEncrypted/*.m
  ${FIREBASE_EXTERNAL_SOURCE_DIR}/GoogleUtilities/GoogleUtilities/Logger/*.m
)
file(
  GLOB headers
  ${FIREBASE_EXTERNAL_SOURCE_DIR}/GoogleUtilities/GoogleUtilities/Environment/Public/GoogleUtilities/*.h
  ${FIREBASE_EXTERNAL_SOURCE_DIR}/GoogleUtilities/GoogleUtilities/Logger/Public/GoogleUtilities/*.h
  ${FIREBASE_EXTERNAL_SOURCE_DIR}/GoogleUtilities/third_party/IsAppEncrypted/Public/*.h
)

firebase_ios_add_framework(
  GoogleUtilities DISABLE_STRICT_WARNINGS EXCLUDE_FROM_ALL
  ${headers} ${sources}
)

# GoogleUtilities
target_include_directories(
  GoogleUtilities PRIVATE
  ${FIREBASE_EXTERNAL_SOURCE_DIR}/GoogleUtilities
)

firebase_ios_framework_public_headers(GoogleUtilities ${headers})

target_link_libraries(
  GoogleUtilities PRIVATE
  "-framework Foundation"
)
