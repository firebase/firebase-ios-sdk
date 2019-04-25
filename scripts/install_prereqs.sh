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

set -ev

bundle install

case "$PROJECT-$PLATFORM-$METHOD" in
  Firebase-iOS-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=Example --repo-update
    bundle exec pod install --project-directory=Functions/Example
    bundle exec pod install --project-directory=GoogleUtilities/Example
    bundle exec pod install --project-directory=GoogleNotificationUtilities/Example

    # Set up GoogleService-Info.plist for Storage and Database integration tests. The decrypting
    # is not supported for pull requests. See https://docs.travis-ci.com/user/encrypting-files/
    if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
      openssl aes-256-cbc -K $encrypted_824e27188cd5_key -iv $encrypted_824e27188cd5_iv \
      -in scripts/travis-encrypted/Secrets.tar.enc \
      -out scripts/travis-encrypted/Secrets.tar -d

      tar xvf scripts/travis-encrypted/Secrets.tar

      cp Secrets/Auth/Sample/Application.plist Example/Auth/Sample/Application.plist
      cp Secrets/Auth/Sample/AuthCredentials.h Example/Auth/Sample/AuthCredentials.h
      cp Secrets/Auth/Sample/GoogleService-Info_multi.plist Example/Auth/Sample/GoogleService-Info_multi.plist
      cp Secrets/Auth/Sample/GoogleService-Info.plist Example/Auth/Sample/GoogleService-Info.plist
      cp Secrets/Auth/Sample/Sample.entitlements Example/Auth/Sample/Sample.entitlements
      cp Secrets/Auth/ApiTests/AuthCredentials.h Example/Auth/ApiTests/AuthCredentials.h

      cp Secrets/Storage/App/GoogleService-Info.plist Example/Storage/App/GoogleService-Info.plist
      cp Secrets/Storage/App/GoogleService-Info.plist Example/Database/App/GoogleService-Info.plist
    fi
    ;;

  Firebase-*-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=Example --repo-update
    bundle exec pod install --project-directory=GoogleUtilities/Example
    bundle exec pod install --project-directory=GoogleNotificationUtilities/Example
    ;;

  Functions-*)
    bundle exec pod repo update
    # Start server for Functions integration tests.
    ./Functions/Backend/start.sh synchronous
    ;;

  InAppMessaging-iOS-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=InAppMessagingDisplay/Example --repo-update
    bundle exec pod install --project-directory=InAppMessaging/Example --repo-update
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

  SymbolCollision-*-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=SymbolCollisionTest --repo-update
    ;;

  GoogleDataTransport-iOS-xcodebuild)
    gem install xcpretty
    bundle exec pod gen GoogleDataTransport.podspec --gen-directory=GoogleDataTransport/gen
    ;;

  GoogleDataTransportCCTSupport-iOS-xcodebuild)
    gem install xcpretty
    # TODO(mikehaney24): Remove the SpecsStaging repo once GDT is published.
    bundle exec pod gen GoogleDataTransportCCTSupport.podspec \
--gen-directory=GoogleDataTransportCCTSupport/gen  \
--sources=https://github.com/Firebase/SpecsStaging.git,https://github.com/CocoaPods/Specs.git
    ;;
  *)
    echo "Unknown project-platform-method combo" 1>&2
    echo "  PROJECT=$PROJECT" 1>&2
    echo "  PLATFORM=$PLATFORM" 1>&2
    echo "  METHOD=$METHOD" 1>&2
    exit 1
    ;;
esac
