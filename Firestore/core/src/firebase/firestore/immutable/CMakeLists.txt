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
  firebase_firestore_immutable
  SOURCES
    array_sorted_map.h
    llrb_node.h
    map_entry.h
    sorted_map.h
    sorted_map_base.h
    sorted_map_base.cc
    tree_sorted_map.h
  DEPENDS
    firebase_firestore_util
)
