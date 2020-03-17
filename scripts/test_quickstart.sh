# Copyright 2019 Google
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


# Run a CI `script` phase to build the associated quickstart
# sample and run its tests.

set -xeuo pipefail

# Set have_secrets to true or false.
. scripts/check_secrets.sh

if [[ "$have_secrets" == true ]]; then
  cd quickstart-ios
  have_secrets="$have_secrets" SAMPLE="$1" ./scripts/test.sh
fi
