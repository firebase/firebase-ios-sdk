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


# Script to run in a CI `before_install` phase to setup the quickstart repo
# so that it can be used for integration testing.

set -xeuo pipefail

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(dirname "$scripts_dir")"

$scripts_dir/setup_bundler.sh

# Source function to check if CI secrets are available.
source $scripts_dir/check_secrets.sh

SAMPLE=$1

RELEASE_TESTING=${2-}

WORKSPACE_DIR="quickstart-ios/${SAMPLE}"
PODFILE="quickstart-ios/"$SAMPLE"/Podfile"

if [[ ! -z "${LEGACY:-}" ]]; then
  WORKSPACE_DIR="quickstart-ios/${SAMPLE}/Legacy${SAMPLE}Quickstart"
  PODFILE="quickstart-ios/"$SAMPLE"/Legacy${SAMPLE}Quickstart/Podfile"
fi


# Installations is the only quickstart that doesn't need a real
# GoogleService-Info.plist for its tests.
if check_secrets || [[ ${SAMPLE} == "installations" ]]; then

  # Specify repo so the Firebase module and header can be found in a
  # development pod install. This is needed for the `pod install` command.
  export FIREBASE_POD_REPO_FOR_DEV_POD=`pwd`

  git clone https://github.com/firebase/quickstart-ios.git
  $scripts_dir/localize_podfile.swift "$WORKSPACE_DIR"/Podfile "$RELEASE_TESTING"
  if [ "$RELEASE_TESTING" == "nightly_release_testing" ]; then
    set +x
    sed -i "" '1i\'$'\n'"source 'https://${BOT_TOKEN}@github.com/FirebasePrivate/SpecsTesting.git'"$'\n' "$PODFILE"
    set -x
    echo "Source of Podfile for nightly release testing is updated."
  fi
  if [ "$RELEASE_TESTING" == "prerelease_testing" ]; then
    set +x
    sed -i "" '1i\'$'\n'"source 'https://${BOT_TOKEN}@github.com/FirebasePrivate/SpecsReleasing.git'"$'\n' "$PODFILE"
    set -x
    echo "Source of Podfile for prerelease testing is updated."
  fi
  cd "${WORKSPACE_DIR}"

  # To test a branch, uncomment the following line
  # git checkout {BRANCH_NAME}

  bundle update --bundler
  bundle install
  pod update

  if [[ ! -z "${LEGACY:-}" ]]; then
    cd ..
  fi

  # Add GoogleService-Info.plist to Xcode project
  ruby ../scripts/info_script.rb "${SAMPLE}" "${LEGACY:-}"
  cd -
fi
