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

bundle install

case "$PROJECT-$PLATFORM-$METHOD" in
  Firebase-iOS-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=Example --repo-update
    bundle exec pod install --project-directory=Functions/Example
    bundle exec pod install --project-directory=GoogleUtilities/Example

    # Set up GoogleService-Info.plist for Storage and Database integration tests. The decrypting
    # is not supported for pull requests. See https://docs.travis-ci.com/user/encrypting-files/
    if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
        openssl aes-256-cbc -K $encrypted_2c8d10c8cc1d_key -iv $encrypted_2c8d10c8cc1d_iv \
            -in scripts/travis-encrypted/database-storage/GoogleService-Info.plist.enc \
            -out Example/Storage/App/GoogleService-Info.plist -d
        cp Example/Storage/App/GoogleService-Info.plist Example/Database/App/GoogleService-Info.plist
    fi
    ;;

  Firebase-*-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=Example --repo-update
    bundle exec pod install --project-directory=GoogleUtilities/Example
    ;;

  Firestore-*-xcodebuild | Firestore-*-fuzz)
    gem install xcpretty
    bundle exec pod install --project-directory=Firestore/Example --repo-update
    ;;

  *-pod-lib-lint)
    bundle exec pod repo update
    ;;

  Firestore-*-cmake)
    brew outdated cmake || brew upgrade cmake
    brew outdated go || brew upgrade go # Somehow the build for Abseil requires this.

    # Install python packages required to generate proto sources
    pip install six
    ;;

  *)
    echo "Unknown project-platform-method combo" 1>&2
    echo "  PROJECT=$PROJECT" 1>&2
    echo "  PLATFORM=$PLATFORM" 1>&2
    echo "  METHOD=$METHOD" 1>&2
    exit 1
    ;;
esac
