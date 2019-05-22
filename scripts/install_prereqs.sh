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

function install_secrets() {
  # Set up secrets for integration tests and metrics collection. This does not work for pull
  # requests from forks. See
  # https://docs.travis-ci.com/user/pull-requests#pull-requests-and-security-restrictions
  if [[ ! -z $encrypted_d6a88994a5ab_key ]]; then
    openssl aes-256-cbc -K $encrypted_d6a88994a5ab_key -iv $encrypted_d6a88994a5ab_iv \
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

    cp Secrets/Metrics/database.config Metrics/database.config
  fi
}

case "$PROJECT-$PLATFORM-$METHOD" in
  Firebase-iOS-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=Example --repo-update
    bundle exec pod install --project-directory=Functions/Example
    bundle exec pod install --project-directory=GoogleUtilities/Example
    install_secrets
    ;;

  Firebase-*-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=Example --repo-update
    bundle exec pod install --project-directory=GoogleUtilities/Example
    ;;

  Functions-*)
    # Start server for Functions integration tests.
    bundle exec pod repo update
    ./Functions/Backend/start.sh synchronous
    ;;

  Database-*)
    # Install the workspace to have better control over test runs than
    # pod lib lint, since the integration tests can be flaky.
    bundle exec pod repo update
    bundle exec pod gen FirebaseDatabase.podspec --local-sources=./
    install_secrets
    ;;

  Storage-*)
    # Install the workspace to have better control over test runs than
    # pod lib lint, since the integration tests can be flaky.
    bundle exec pod repo update
    bundle exec pod gen FirebaseStorage.podspec --local-sources=./
    install_secrets
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

  GoogleDataTransport-*-xcodebuild)
    gem install xcpretty
    bundle exec pod gen GoogleDataTransport.podspec --gen-directory=GoogleDataTransport/gen
    ;;

  GoogleDataTransportIntegrationTest-*-xcodebuild)
    gem install xcpretty
    bundle exec pod gen GoogleDataTransport.podspec --gen-directory=GoogleDataTransport/gen
    ;;

  GoogleDataTransportCCTSupport-*-xcodebuild)
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
