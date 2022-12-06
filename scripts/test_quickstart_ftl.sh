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


# This script is modified from test_quickstart.sh.
# Run a CI `script` phase to build the associated quickstart sample
# and generate build-for-testing artfacts, which can be used to
# run test on Firebase Test Lab.
# The artifacts are under dir: `quickstart-ios/build-for-testing`

set -xeuo pipefail

sample="$1"
language="${2-}"

# Source function to check if CI secrets are available.
source scripts/check_secrets.sh

if check_secrets; then
  cd quickstart-ios
  if [ "$language" = "swift" ]; then
    have_secrets=true SAMPLE="$sample" SWIFT_SUFFIX="Swift" ./scripts/build-for-testing.sh
  else
    have_secrets=true SAMPLE="$sample" ./scripts/build-for-testing.sh
  fi

fi
