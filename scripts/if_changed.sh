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

# Within Travis, runs the given command if the current project has changes
# worth building.
#
# Examines the following Travis-supplied environment variables:
#   - TRAVIS_PULL_REQUEST - the PR number or false for full build
#   - TRAVIS_COMMIT_RANGE - the range of commits under test; empty on a new
#     branch
#
# Also examines the following configured environment variables that should be
# specified in an env: block
#   - PROJECT - Firebase or Firestore
#   - METHOD - xcodebuild or cmake

function check_changes() {
  if git diff --name-only "$TRAVIS_COMMIT_RANGE" | grep -Eq "$1"; then
    run=true
  fi
}

run=false

# To force Travis to do a full run, change the "false" to "{PR number}" like
# if [[ "$TRAVIS_PULL_REQUEST" == "904" ]]; then
if [[ "$TRAVIS_PULL_REQUEST" == "false" ]]; then
  # Full builds should run everything
  run=true

elif [[ -z "$TRAVIS_COMMIT_RANGE" ]]; then
  # First builds on a branch should also run everything
  run=true

else
  case "$PROJECT-$METHOD" in
    Firebase-pod-lib-lint) # Combines Firebase-* and InAppMessaging*
      check_changes '^(FirebaseAuth|FirebaseDatabase|Firebase/DynamicLinks|'\
'FirebaseMessaging|FirebaseStorage|GoogleUtilities|Interop|Example|'\
'FirebaseAnalyticsInterop.podspec|FirebaseAuth.podspec|FirebaseAuthInterop.podspec|'\
'FirebaseCoreDiagnostics.podspec|FirebaseCoreDiagnosticsInterop.podspec|'\
'FirebaseDatabase.podspec|FirebaseDynamicLinks.podspec|FirebaseMessaging.podspec|'\
'FirebaseStorage.podspec|'\
'InAppMessaging|Firebase/InAppMessaging|'\
'FirebaseInAppMessaging.podspec|'\
'FirebaseInstallations|'\
'FirebaseCrashlytics.podspec)'\
      ;;

    FirebasePod-*)
      check_changes '^(CoreOnly|Firebase.podspec)'
      ;;

    Core-*)
      check_changes '^(FirebaseCore|Example/Core/Tests|GoogleUtilities|FirebaseCore.podspec'\
'Firebase/CoreDiagnostics|Example/CoreDiagnostics/Tests|FirebaseCoreDiagnostics.podspec|'\
'FirebaseCoreDiagnosticsInterop|FirebaseCoreDiagnosticsInterop.podspec)'
      ;;

    ABTesting-*)
      check_changes '^(FirebaseCore|FirebaseABTesting)'
      ;;

    Auth-*)
      check_changes '^(FirebaseCore|FirebaseAuth|GoogleUtilities|FirebaseAuth.podspec)'
      ;;

    Crashlytics-*)
      check_changes '^(FirebaseCore|GoogleUtilities|Crashlytics|FirebaseCrashlytics.podspec|'\
'FirebaseInstallations|GoogleDataTransport|GoogleDataTransport.podspec)'
      ;;

    Database-*)
      check_changes '^(FirebaseCore|FirebaseDatabase|GoogleUtilities|FirebaseDatabase.podspec|'\
'scripts/run_database_emulator.sh)'
      ;;

    DynamicLinks-*)
      check_changes '^(FirebaseCore|Firebase/DynamicLinks|Example/DynamicLinks|GoogleUtilities|FirebaseDynamicLinks.podspec)'
      ;;

    Functions-*)
      check_changes '^(FirebaseCore|Functions|GoogleUtilities|FirebaseFunctions.podspec)'
      ;;

    GoogleUtilities-*)
      check_changes '^(GoogleUtilities|GoogleUtilities.podspec)'
      ;;

    GoogleUtilitiesComponents-*)
      check_changes '^(GoogleUtilities|GoogleUtilitiesComponents|GoogleUtilitiesComponents.podspec)'
      ;;

    InAppMessaging-*)
      check_changes '^(FirebaseInAppMessaging|'\
'FirebaseInAppMessaging.podspec|'\
'FirebaseInstallations)'
      ;;

    Firestore-xcodebuild|Firestore-pod-lib-lint)
      check_changes '^(Firestore|FirebaseFirestore.podspec|FirebaseFirestoreSwift.podspec|'\
'GoogleUtilities|scripts/run_firestore_emulator.sh)'
      ;;

    Firestore-cmake)
      check_changes '^(Firestore/(core|third_party)|cmake|FirebaseCore|GoogleUtilities|)'\
'scripts/run_firestore_emulator.sh)'
      ;;

    GoogleDataTransport-*)
      check_changes '^(GoogleDataTransport|GoogleDataTransport.podspec)'
      ;;

    Messaging-*)
      check_changes '^(FirebaseCore|FirebaseMessaging|GoogleUtilities|FirebaseMessaging.podspec|'\
'FirebaseInstallations)'
      ;;

    RemoteConfig-*)
      check_changes '^(FirebaseCore|FirebaseRemoteConfig|FirebaseRemoteConfig.podspec|'\
'FirebaseInstallations)'
      ;;

    Storage-*)
      check_changes '^(FirebaseCore|FirebaseStorage|GoogleUtilities|FirebaseStorage.podspec)'
      ;;

    Installations-*)
      check_changes '^(FirebaseCore|GoogleUtilities|FirebaseInstallations)'
      ;;

    *)
      echo "Unknown project-method combo" 1>&2
      echo "  PROJECT=$PROJECT" 1>&2
      echo "  METHOD=$METHOD" 1>&2
      exit 1
      ;;
  esac
fi

# Always rebuild if Travis configuration and/or build scripts changed.
check_changes '^.travis.yml'
check_changes '^Gemfile.lock'
check_changes '^scripts/(build|install_prereqs|pod_lib_lint).(rb|sh)'
check_changes '^scripts/xcresult_logs.py'

if [[ "$run" == true ]]; then
  "$@"
else
  echo "skipped $*"
fi

