#!/bin/bash

# Copyright 2022 Google LLC
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
#

readonly DIR="$( git rev-parse --show-toplevel )"

#
# Use the following command in this comment if you're iterating on the
# podspec. This will prevent settings from changing when you reload the project.
#
# pod gen FirebaseSessions.podspec --local-sources=./ --auto-open --platforms=ios,macos,tvos
#
pod gen "${DIR}/FirebaseSessions.podspec" --auto-open --gen-directory="${DIR}/gen" --local-sources="${DIR}" --platforms=ios,macos,tvos --clean

