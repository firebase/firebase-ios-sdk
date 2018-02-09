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

cc_test(
  firebase_firestore_model_test
  SOURCES
    database_id_test.cc
    field_path_test.cc
    field_value_test.cc
    snapshot_version_test.cc
    timestamp_test.cc
    resource_path_test.cc
  DEPENDS
    firebase_firestore_model
)
