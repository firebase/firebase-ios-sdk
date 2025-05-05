# Copyright 2025 Google LLC
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


# Modify a .xcodeproj to use a specific branch.
# TODO: Update to transform from a release, as well as from `main`.

set -xeuo pipefail

SAMPLE=$1
XCODEPROJ=${SAMPLE}/${SAMPLE}Example.xcodeproj/project.pbxproj

if grep -q "branch = main;" ${XCODEPROJ}; then
  sed -i "" "s#branch = main;#branch = $BRANCH_NAME;#" ${XCODEPROJ}
else
  echo "Failed to update quickstart's Xcode project to the current branch"
  exit 1
fi
