#!/usr/bin/env bash

# Copyright 2018 Google LLC
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
#   - METHOD - xcodebuild, cmake, or cmake_fuzzing; default is xcodebuild

set -euo pipefail

# Set up secrets for integration tests and metrics collection. This does not work for pull
# requests from forks. See
# https://docs.travis-ci.com/user/pull-requests#pull-requests-and-security-restrictions
function install_secrets() {
  if [[ -n "${encrypted_de2056405dcb_key:-}" && $secrets_installed != true ]]; then
    secrets_installed=true
    openssl aes-256-cbc -K $encrypted_de2056405dcb_key -iv $encrypted_de2056405dcb_iv \
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

# apt_install program package
#
# Installs the given package if the given command is missing
function apt_install() {
  local program="$1"
  local package="$2"
  which "$program" >& /dev/null || sudo apt-get install "$package"
}

function install_xcpretty() {
  gem install xcpretty
  if [[ -n "${TRAVIS:-}" ]]; then
    gem install xcpretty-travis-formatter
  fi
}

secrets_installed=false

# Default values, if not supplied on the command line or environment
platform="iOS"
method="xcodebuild"

if [[ $# -eq 0 ]]; then
  # Take arguments from the environment
  project=$PROJECT
  platform=${PLATFORM:-${platform}}
  method=${METHOD:-${method}}

else
  project="$1"

  if [[ $# -gt 1 ]]; then
    platform="$2"
  fi

  if [[ $# -gt 2 ]]; then
    method="$3"
  fi
fi

echo "Installing prerequisites for $project for $platform using $method"

if [[ "$method" != cmake* ]]; then
  scripts/setup_bundler.sh
fi

if [[ ! -z "${QUICKSTART:-}" ]]; then
  install_secrets
  scripts/setup_quickstart.sh "$QUICKSTART"
fi

case "$project-$platform-$method" in

  FirebasePod-iOS-xcodebuild)
    install_xcpretty
    bundle exec pod install --project-directory=CoreOnly/Tests/FirebasePodTest --repo-update
    ;;

  Auth-*)
    # Install the workspace for integration testing.
    install_xcpretty
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
    install_xcpretty
    bundle exec pod install --project-directory=FirebaseInAppMessaging/Tests/Integration/DefaultUITestApp --no-repo-update
    ;;

  Firestore-*-xcodebuild | Firestore-*-fuzz)
    install_xcpretty

    # The Firestore Podfile is multi-platform by default, but this doesn't work
    # with command-line builds using xcodebuild. The PLATFORM environment
    # variable forces the project to be set for just that single platform.
    export PLATFORM="$platform"
    bundle exec pod install --project-directory=Firestore/Example --repo-update
    ;;

  Firestore-iOS-cmake | Firestore-tvOS-cmake | Firestore-macOS-cmake)
    brew outdated cmake || brew upgrade cmake
    brew outdated go || brew upgrade go # Somehow the build for Abseil requires this.
    brew install ccache
    brew install ninja

    # Install python packages required to generate proto sources
    pip install six
    ;;

  Firestore-Linux-cmake | Firestore-Linux-cmake_fuzzing)
    apt_install ccache ccache
    apt_install cmake cmake
    apt_install go golang-go
    apt_install ninja ninja-build

    # Install python packages required to generate proto sources
    pip install six
    ;;

  SymbolCollision-*-xcodebuild)
    install_xcpretty
    bundle exec pod install --project-directory=SymbolCollisionTest --repo-update
    ;;

  *-pod-lib-lint)
    ;;

  *)
    echo "Unknown project-platform-method combo" 1>&2
    echo "  PROJECT=$project" 1>&2
    echo "  PLATFORM=$platform" 1>&2
    echo "  METHOD=$method" 1>&2
    exit 1
    ;;
esac
