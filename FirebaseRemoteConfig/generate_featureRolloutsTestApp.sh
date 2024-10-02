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
# This script attempts to copy the Google Services file from google3. If you are not a Google Employee, it will fail, so we'd recommend you create your own Firebase App and place the Google Services file in Tests/TestApp/Shared
#

echoColor() {
  COLOR='\033[0;35m'
  NC='\033[0m'
  printf "${COLOR}$1${NC}\n"
}

echoRed() {
  COLOR='\033[0;31m'
  NC='\033[0m'
  printf "${COLOR}$1${NC}\n"
}

echoColor "Generating Firebase Remote Config Feature Rolouts Test App"
echoColor "Copying GoogleService-Info.plist from google3. Checking gcert status"
if gcertstatus; then
  G3Path="/google/src/files/head/depot/google3/third_party/firebase/ios/Secrets/RemoteConfig/FeatureRollouts/GoogleService-Info.plist"
  Dest="$DIR/FirebaseRemoteConfig/Tests/FeatureRolloutsTestApp/Shared"
  cp $G3Path $Dest
  echoColor "Copied $G3Path to $Dest"
else
  echoRed "gcert token is not valid. If you are a Google Employee, run 'gcert', and then repeat this command. Non-Google employees will need to download a GoogleService-Info.plist and place it in $DIR/FirebaseRemoteConfig/Tests/FeatureRolloutsTestApp"
fi


echoColor "Running 'pod install'"
cd $DIR/FirebaseRemoteConfig/Tests/FeatureRolloutsTestApp
pod install

# Upon a `pod install`, Crashlytics will copy these files at the root directory
# due to a funky interaction with its cocoapod. This line deletes these extra
# copies of the files as they should only live in Crashlytics/
rm -f $DIR/run $DIR/upload-symbols

open *.xcworkspace

