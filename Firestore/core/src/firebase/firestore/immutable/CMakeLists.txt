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

firebase_ios_cc_library(
  firebase_firestore_immutable
  SOURCES
    append_only_list.h
    array_sorted_map.h
    keys_view.h
    llrb_node.h
    llrb_node_iterator.h
    sorted_container.h
    sorted_container.cc
    sorted_map.h
    sorted_map_iterator.h
    sorted_set.h
    tree_sorted_map.h
  DEPENDS
    absl_base
    firebase_firestore_util
)
