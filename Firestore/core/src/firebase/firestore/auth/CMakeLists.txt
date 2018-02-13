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

cc_library(
  firebase_firestore_auth_base
  SOURCES
    credentials_provider.cc
    credentials_provider.h
    token.cc
    token.h
    user.cc
    user.h
  DEPENDS
    absl_strings
    firebase_firestore_util
)

cc_library(
  firebase_firestore_auth_apple
  SOURCES
    firebase_credentials_provider_apple.h
    firebase_credentials_provider_apple.mm
  DEPENDS
    FirebaseCore
    firebase_firestore_auth_base
  EXCLUDE_FROM_ALL
)

if(APPLE)
  list(APPEND AUTH_DEPENDS firebase_firestore_auth_apple)
endif()

cc_library(
  firebase_firestore_auth
  SOURCES
    empty_credentials_provider.cc
    empty_credentials_provider.h
  DEPENDS
    ${AUTH_DEPENDS}
    firebase_firestore_auth_base
)
