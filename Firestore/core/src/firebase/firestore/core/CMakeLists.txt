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
  firebase_firestore_core
  SOURCES
    array_contains_any_filter.cc
    array_contains_any_filter.h
    array_contains_filter.cc
    array_contains_filter.h
    bound.cc
    bound.h
    database_info.cc
    database_info.h
    direction.cc
    direction.h
    field_filter.cc
    field_filter.h
    filter.cc
    filter.h
    in_filter.cc
    in_filter.h
    key_field_in_filter.cc
    key_field_in_filter.h
    key_field_filter.cc
    key_field_filter.h
    listen_options.h
    operator.h
    order_by.cc
    order_by.h
    query.cc
    query.h
    query_listener.cc
    query_listener.h
    target_id_generator.cc
    target_id_generator.h
    user_data.cc
    user_data.h
    view.cc
    view.h
    view_snapshot.cc
    view_snapshot.h
  DEPENDS
    absl_strings
    firebase_firestore_model
    firebase_firestore_objc
    firebase_firestore_remote
)
