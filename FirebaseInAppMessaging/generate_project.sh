#!/bin/bash

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
#

readonly REPO_DIR="$( git rev-parse --show-toplevel )"

"$REPO_DIR/FirebaseInAppMessaging/ProtoSupport/generate_nanopb_protos.sh" || {
  echo "Something went wrong generating protos."
  exit 1
}

pod gen "${REPO_DIR}/FirebaseInAppMessaging.podspec" --auto-open --gen-directory="${REPO_DIR}/gen" --local-sources="${REPO_DIR}/" --clean
