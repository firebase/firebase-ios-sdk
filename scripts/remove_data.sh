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

set -xe

SDK="$1"
MODE=${2-}

DIR="${SDK}"

if [[ ! -z "$LEGACY" ]]; then
  DIR="${SDK}/Legacy${SDK}Quickstart"
fi


if [ "$MODE" == "release_testing" ]; then
  echo "Update podfiles release_testing."
  sed -i "" "s/https:\/\/.*@github.com\/FirebasePrivate\/SpecsTesting.git/https:\/\/github.com\/FirebasePrivate\/SpecsTesting.git/g" quickstart-ios/"${DIR}"/Podfile quickstart-ios/"${DIR}"/Podfile.lock
fi
rm -f quickstart-ios/"${DIR}"/GoogleService-Info.plist
