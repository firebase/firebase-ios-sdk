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


# Script to run in a CI `before_install` phase to setup the quickstart repo
# so that it can be used for integration testing.

SAMPLE=$1
git clone https://github.com/firebase/quickstart-ios.git
cd quickstart-ios/"$SAMPLE"
bundle exec pod install --repo-update
../scripts/install_prereqs/"$SAMPLE.sh"
# Secrets are repo specific, so we need to override with the firebase-ios-sdk
# version.
cp ../../scripts/Secrets/quickstart-ios/"$SAMPLE"/GoogleService-Info.plist ./
cd -
