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
  if [[ ! -z $encrypted_d6a88994a5ab_key && $secrets_installed != true ]]; then
    secrets_installed=true
    openssl aes-256-cbc -K $encrypted_5dda5f491369_key -iv $encrypted_5dda5f491369_iv \
    -in scripts/travis-encrypted/Secrets.tar.enc \
    -out scripts/travis-encrypted/Secrets.tar -d

    tar xvf scripts/travis-encrypted/Secrets.tar

    cp Secrets/Auth/Sample/Application.plist Example/Auth/Sample/Application.plist
    cp Secrets/Auth/Sample/AuthCredentials.h Example/Auth/Sample/AuthCredentials.h
    cp Secrets/Auth/Sample/GoogleService-Info_multi.plist Example/Auth/Sample/GoogleService-Info_multi.plist
    cp Secrets/Auth/Sample/GoogleService-Info.plist Example/Auth/Sample/GoogleService-Info.plist
    cp Secrets/Auth/Sample/Sample.entitlements Example/Auth/Sample/Sample.entitlements
    cp Secrets/Auth/ApiTests/AuthCredentials.h Example/Auth/ApiTests/AuthCredentials.h

    cp Secrets/Storage/App/GoogleService-Info.plist FirebaseStorage/Tests/Integration/Resources/GoogleService-Info.plist
    cp Secrets/Storage/App/GoogleService-Info.plist Example/Database/App/GoogleService-Info.plist

    cp Secrets/Metrics/database.config Metrics/database.config

    # Firebase Installations
    fis_resources_dir=FirebaseInstallations/Source/Tests/Resources/
    mkdir -p "$fis_resources_dir"
    cp Secrets/Installations/GoogleService-Info.plist "$fis_resources_dir"

    # FirebaseInstanceID
    iid_resources_dir=Example/InstanceID/Resources/
    mkdir -p "$iid_resources_dir"
    cp Secrets/Installations/GoogleService-Info.plist "$iid_resources_dir"
  fi
}

if [[ ! -z $QUICKSTART ]]; then
  install_secrets
  ./scripts/setup_quickstart.sh "$QUICKSTART"
fi

case "$PROJECT-$PLATFORM-$METHOD" in

  FirebasePod-iOS-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=CoreOnly/Tests/FirebasePodTest --repo-update
    ;;

  Auth-*)
    # Install the workspace for integration testing.
    gem install xcpretty
    bundle exec pod install --project-directory=Example/Auth/AuthSample --repo-update
    ;;

  Crashlytics-*)
    ;;

  Database-*)
    ;;

  Functions-*)
    # Start server for Functions integration tests.
    ./Functions/Backend/start.sh synchronous
    ;;

  Storage-*)
    ;;

  Installations-*)
    install_secrets
    ;;

  InstanceID*)
    install_secrets
    ;;

  InAppMessaging-*-xcodebuild)
    gem install xcpretty
    bundle exec pod install --project-directory=InAppMessaging/Example --repo-update
    bundle exec pod install --project-directory=InAppMessagingDisplay/Example --no-repo-update
    ;;

  Firestore-*-xcodebuild | Firestore-*-fuzz)
    if [[ $XCODE_VERSION == "8."* ]]; then
      # Firestore still compiles with Xcode 8 to help verify general
      # conformance with C++11 by using an older compiler that doesn't have as
      # many extensions from later versions of the language. However, Firebase
      # as a whole does not support this environment and @available checks in
      # GoogleDataTransport would otherwise break this build.
      #
      # This drops the dependency that adds GoogleDataTransport into
      # Firestore's dependencies.
      sed -i.bak "/s.dependency 'FirebaseCoreDiagnostics'/d" FirebaseCore.podspec
    fi

    gem install xcpretty
    bundle exec pod install --project-directory=Firestore/Example --repo-update
    ;;

  *-pod-lib-lint)
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

  *)
    echo "Unknown project-platform-method combo" 1>&2
    echo "  PROJECT=$PROJECT" 1>&2
    echo "  PLATFORM=$PLATFORM" 1>&2
    echo "  METHOD=$METHOD" 1>&2
    exit 1
    ;;
esac
