# Firebase Apple Scripts

This directory provides a set of scripts for development, test, and continuous
integration of the Firebase Apple SDKs.

## [check.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check.sh)

Used by the
[check CI workflow](https://github.com/firebase/firebase-ios-sdk/blob/main/.github/workflows/check.yml)
to run several static analysis checks. It calls the following scripts:

### [style.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/style.sh)

Runs clang-format and swiftformat across the repo.

### [check_whitespace.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check_whitespace.sh)

Verify there are no files with trailing whitespace.

### [check_filename_spaces.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check_filename_spaces.sh)

Spaces in filenames are not allowed.

### [check_copyright.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check_copyright.sh)

Verify existence and format of copyrights.

### [check_test_inclusion.py](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check_test_inclusion.py)

Test existence check for the internal Firestore Xcode project.

### [check_imports.swift](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check_imports.swift)

Verify import style complies with
[repo standards](https://github.com/firebase/firebase-ios-sdk/blob/main/HeadersImports.md).

### [check_firestore_core_api_absl.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check_firestore_core_api_absl.sh)

Check Firestore `absl` usages for g3 build issues.

### [check_lint.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check_lint.sh)

Run cpplint.

### [sync_project.rb](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/sync_project.rb)

Used by Firestore to to keep the Xcode project in sync after adding/removing tests.

## Other Scripts
### [binary_to_array.py](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/binary_to_array.py)

Firestore script to convert binary data into a C/C++ array.

### [build.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/build.sh)

Script used by CI jobs to wrap xcodebuild invocations with options.

### [build_non_firebase_sdks.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/build.sh)

CI script to build binary versions of non-Firebase SDKs for QuickStart testing.

### [build_zip.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/build_zip.sh)

CI script for building the zip distribution.

### [buildcache.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/buildcache.sh)

Clang options for the buildcache GitHub action.

### [change_headers.swift](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/change_headers.swift)

Utility script to update source to repo-relative headers.

### [check_secrets.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check_secrets.sh)

CI script to test if secrets are available (not running on a fork).

### [collect_metrics.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/collect_metrics.sh)

CI script to collect project health metrics and upload them to a database.

### [configure_test_keychain.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/configure_test_keychain.sh)

CI script to setup the keychain for macOS and Catalyst testing.

### [cpplint.py](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/cpplint.py)

Firestore script for C++ linting.

### [create_pull_request.rb](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/create_pull_request.rb)

Utility used by CI scripts to create issues and PRs.

### [decrypt_gha_secret.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/decrypt_gha_secret.sh)

CI script to decrypt a GitHub Actions secret.

### [encrypt_gha_secret.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/encrypt_gha_secret.sh)

CI script to encrypt a GitHub Actions secret.

### [fuzzing_ci.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/fuzzing_ci.sh)

Firestore CI script to run fuzz testing.

### [generate_access_token.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/generate_access_token.sh)

Script to generate a Firebase access token used by Remote config integration tests.

### [install_prereqs.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scriptsinstall_prereqs.sh)

Utility CI script to provide configuration for build.sh

### [localize_podfile.swift](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/localize_podfile.swift)

Utility script to update a Podfile to point to local podspecs.

### [make_release_notes.py](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/make_release_notes.py)

Converts GitHub-flavored markdown changelogs to devsite-compatible release notes.

### [pod_lib_lint.rb](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/pod_lib_lint.rb)

Wrapper script for running `pod lib lint` tests to include dependencies from the monorepo.

### [release_testing_setup.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/release_testing_setup.sh)

Utility script for the release workflow.

### [remove_data.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/remove_data.sh)

Cleanup script for CI workflows.

### [run_database_emulator.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/run_database_emulator.sh)

Run the RTDB emulator.

### [run_firestore_emulator.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/run_firestore_emulator.sh)

Run the Firestore emulator.

### [setup_bundler.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/setup_bundler.sh)

Set up the Ruby bundler.

### [setup_check.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/setup_check.sh)

Install tooling for the check workflow.

### [setup_quickstart.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/setup_quickstart.sh)

Set up a QuickStart for integration testing.

### [setup_quickstart_framework.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/setup_quickstart_framework.sh)

Set up a QuickStart for zip distribution testing.

### [setup_spm_tests.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/setup_spm_tests.sh)

Configuration for SPM testing.

### [spm_test_schemes/](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/spm_test_schemes)

Schemes used by above script to enable test target schemes.

### [test_archiving.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/test_archiving.sh)

Test Xcode Archive build.

### [test_catalyst.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/test_catalyst.sh)

Test catalyst build.

### [test_quickstart.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/test_quickstart.sh)

Test QuickStart.

### [test_quickstart_framework.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/test_quickstart_framework.sh)

Test QuickStart with the zip distribution.

### [update_xcode_target.rb](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/update_xcode_target.rb)

Script to add a file to an Xcode target.

### [update_vertexai_responses.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/update_vertexai_responses.sh)

Downloads mock response files for Vertex AI unit tests.

### [xcresult_logs.py](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/xcresult_logs.py)

Tooling used by `build.sh` to get the log output for an `xcodebuild` invocation.

### [zip_quickstart_test.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/zip_quickstart_test.sh)

Run the tests associated with a QuickStart with a zip distribution.

## Script Subdirectories
### [create_spec_repo](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/create_spec_repo)

Swift utility to build a podspec repo.

### [gha-encrypted](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/gha-encrypted)

Store for GitHub secret encrypted resources.

### [health_metrics](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/health_metrics)

Code coverage and binary size tooling.

### [lib](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/lib)

Support libraries for `xcresult_logs.py`.

### [lldb](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/lldb)

Firestore utilities.

### [third_party](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/third_party)

Use Travis's MIT licensed retry.sh script.
