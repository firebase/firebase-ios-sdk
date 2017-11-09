#!/bin/bash

# Copyright 2017 Google
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

find . \
    -name 'third_party' -prune -o \
    -name 'Auth' -prune -o \
    -name 'AuthSamples' -prune -o \
    -name 'Database' -prune -o \
    -name 'FirebaseCommunity.h' -prune -o \
    -name 'Messaging' -prune -o \
    -name 'Pods' -prune -o \
    \( -name '*.[mh]' -o -name '*.mm' \) \
    -not -name '*.pbobjc.*' \
    -not -name '*.pbrpc.*' \
    -print0 | xargs -0 clang-format -style=file -i
