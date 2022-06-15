# Firebase Apple SDK Continuous Integration

Firebase uses [several GitHub Action
workflows](https://github.com/firebase/firebase-ios-sdk/tree/master/.github/actions/)
for product testing.

There are two types of tests:
1. Presubmit tests: triggered by a PR when changing specific files
2. Nightly tests: run once a day, scheduled overnight. Potentially longer-running tests.

Presubmit tests are also scheduled to run overnight, independent of PRs.

## Organization

Each Firebase product has a corresponding
[workflow](https://github.com/firebase/firebase-ios-sdk/tree/master/.github/workflows). There
are several other workflows primarily for productization and packaging specific testing.

### Product Testing

Each product workflow has several jobs. The jobs typically matrix across all platforms the product
supports.

#### `pod lib lint` Tests

Use CocoaPods to build, unit test, and run the Xcode Analyzer on the product.

#### SPM Tests

Use Swift Package Manager to build and usually unit test the product.

#### QuickStart Tests

Build and test the product's QuickStart.

#### Integration Tests

Run integration tests for the product. These either use a GitHub secret to access a Firebase project
or use the Firebase emulator.

#### Cron Tests

Tests that only run in the nightly cron run. This is typically the `--static-framework` CocoaPods
configuration that rarely breaks if dynamic frameworks are working.

### Style Tests
[check.yml](https://github.com/firebase/firebase-ios-sdk/tree/master/.github/workflows/check.yml)

Runs several coding style tests. Details to come in an upcoming document about the scripts
directory.

### SwiftPM Tests
[spm.yml](https://github.com/firebase/firebase-ios-sdk/tree/master/.github/workflows/spm.yml)

Build and run Firebase-wide tests with Swift Package Manager.

### Zip Distribution Testing
[zip.yml](https://github.com/firebase/firebase-ios-sdk/tree/master/.github/workflows/zip.yml)

Builds the zip distribution both from the tip of `master` and the current staged release distribution.
The resulting distribution is then used to build and test several Firebase QuickStarts.

### Release testing
[scripts/create_spec_repo](https://github.com/firebase/firebase-ios-sdk/tree/master//scripts/create_spec_repo)

Release testing is to build up a testing podspecs (CocoaPods podspecs) candidate and test building
up a quickstart with CocoaPods. If this candidate is successfully built, that means tests in
podspecs, e.g. abtesting test spec, passed and it is a positive signal to build up a release
candidate.

Currently we have two workflows running nightly to test podspecs:

#### Release workflow
[release.yml](https://github.com/firebase/firebase-ios-sdk/tree/master/.github/workflows/release.yml)

The release workflow is to test podspecs on the latest release branch, and create a testing repo.
This branch is having all podspecs prepared for the next release. Podspecs in this testing repo
will have tags `Cocoapods-X.Y.Z`. This is to mimic a real released candidate. The next step for this
repo is to generate a releasable candidate.

#### Prerelease workflow
[prerelease.yml](https://github.com/firebase/firebase-ios-sdk/tree/master/.github/workflows/prerelease.yml)

The prerelease workflow is to test podspecs on the `master` branch, and create a testing repo. This is
to make sure podspecs are releasable, which means podspecs in the head can pass all tests and build
up a candidate. The next step is to enable presubmit for PRs of podspecs changes on the prerelease
testing repo. This will accelerate the tests of podspecs, which are currently run nightly.

### `pod spec lint` testing
[scripts/create_spec_repo](https://github.com/firebase/firebase-ios-sdk/tree/master/scripts/create_spec_repo)

The previous setup will run podspecs testing nightly. This enables presubmits of pod spec lint
podspecs and accelerates the testing process. This is to run presubmit tests for Firebase Apple SDKs
in the SDK repo. A job to run `pod spec lint` is added to SDK testing workflows, including ABTesting,
Analytics, Auth, Core, Crashlytics, Database, DynamicLinks, Firestore, Functions, GoogleUtilities,
InAppMessaging, Installations, Messaging, MLModelDownloader, Performance, RemoteConfig and Storage.
These jobs will be triggered in presubmit and run pod spec lint with a source of
Firebase/SpecsTesting repo, which is updated to the head of master nightly in the prerelease
workflow.

When these PRs are merged, then changed podspecs will be pod repo push to the Firebase/SpecsTesting
repo, through `update_SpecTesting_repo` job in the prerelease workflow, to make sure the podspec
repo is up-to-date.

### Daily Test Status Notification
[generate_issues.yml](https://github.com/firebase/firebase-ios-sdk/tree/master/.github/workflows/generate_issues.yml)

Generates a testing report for all nightly jobs, like #7797, so developers from the iOS SDK repo do
not have to go through workflows to get all results.

### Code coverage
[test_coverage.yml](https://github.com/firebase/firebase-ios-sdk/tree/master/.github/workflows/test_coverage.yml)

Generates code coverage reports in PRs (see
[example](https://github.com/firebase/firebase-ios-sdk/pull/7788#issuecomment-807690514)).
The workflow will trigger podspec
tests if changed files follow file patterns. Tests will create xcresult bundles, which contain all
code coverage data. These bundles will be gathered in the last job and generate a json report which
will be sent to the Metrics Service, which will create a code coverage report in a PR. Currently
code coverage can generate diff between commits. The next step is to generate incremental code
coverage.

