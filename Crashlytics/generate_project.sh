#!/bin/bash

# Copyright 2020 Google LLC
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

"$DIR/Crashlytics/ProtoSupport/generate_crashlytics_protos.sh" || echo "Something went wrong generating protos.";

pod gen "${DIR}/FirebaseCrashlytics.podspec" --auto-open --gen-directory="${DIR}/gen" --local-sources="${DIR}" --platforms=ios,macos,tvos --clean

# Upon a `pod install`, Crashlytics will copy these files at the root directory
# due to a funky interaction with its cocoapod. This line deletes these extra
# copies of the files as they should only live in Crashlytics/
rm -f $DIR/run $DIR/upload-symbols
