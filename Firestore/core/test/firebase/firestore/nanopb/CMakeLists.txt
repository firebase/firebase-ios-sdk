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

firebase_ios_cc_test(
  firebase_firestore_nanopb_test
  SOURCES
    byte_string_test.cc
    message_test.cc
    nanopb_testing.h
    pretty_printing_test.cc
    writer_test.cc
  DEPENDS
    GMock::GMock
    firebase_firestore_nanopb
    firebase_firestore_remote
    firestore_testutil
)
