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
  firebase_firestore_core_test
  SOURCES
    database_info_test.cc
    event_manager_test.cc
    field_filter_test.cc
    query_listener_test.cc
    query_test.cc
    target_id_generator_test.cc
    view_snapshot_test.cc
    view_test.cc
  DEPENDS
    GMock::GMock
    firebase_firestore_core
    firestore_testutil
)
