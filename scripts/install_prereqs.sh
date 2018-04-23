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

# Within Travis, installs prerequisites for a build.

# Examines the following configured environment variables that should be
# specified in an env: block
#   - PROJECT - Firebase or Firestore
#   - METHOD - xcodebuild or cmake; default is xcodebuild

if [[ -z "$METHOD" ]]; then
  METHOD="xcodebuild"
fi

case "$PROJECT-$METHOD" in
  *-xcodebuild)
    bundle install
    gem install xcpretty
    ;;

  Firestore-cmake)
    bundle install
    # xcpretty is helpful for the intermediate step which builds FirebaseCore
    # using xcodebuild.
    gem install xcpretty
    brew outdated cmake || brew upgrade cmake
    brew outdated go || brew upgrade go # Somehow the build for Abseil requires this.
    ;;

  *)
    echo "Unknown project-method combo" 1>&2
    echo "  PROJECT=$PROJECT" 1>&2
    echo "  METHOD=$METHOD" 1>&2
    exit 1
    ;;
esac
