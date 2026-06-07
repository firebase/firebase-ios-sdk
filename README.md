<p align="center">
  <a href="https://cocoapods.org/pods/Firebase">
    <img src="https://img.shields.io/github/v/release/Firebase/firebase-ios-sdk?style=flat&label=CocoaPods"/>
  </a>
  <a href="https://swiftpackageindex.com/firebase/firebase-ios-sdk">
    <img src="https://img.shields.io/github/v/release/Firebase/firebase-ios-sdk?style=flat&label=Swift%20Package%20Index&color=red"/>
  </a>
  <a href="https://cocoapods.org/pods/Firebase">
    <img src="https://img.shields.io/github/license/Firebase/firebase-ios-sdk?style=flat"/>
  </a><br/>
  <a href="https://swiftpackageindex.com/firebase/firebase-ios-sdk">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ffirebase%2Ffirebase-ios-sdk%2Fbadge%3Ftype%3Dplatforms"/>
  </a>
  <a href="https://swiftpackageindex.com/firebase/firebase-ios-sdk">
    <img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ffirebase%2Ffirebase-ios-sdk%2Fbadge%3Ftype%3Dswift-versions"/>
  </a>
</p>

> [!WARNING] > **CocoaPods:** New versions of the Firebase Apple SDK will no longer be
> published to CocoaPods after **October 2026**. Existing CocoaPods versions
> will remain available and installations will remain functional. See the
> [migration guide](https://firebase.google.com/docs/ios/cocoapods-deprecation)
> for more information.

# Firebase Apple Open Source Development

This repository contains the source code for all Apple platform Firebase
libraries except `FirebaseAnalytics`.

Firebase is an app development platform with libraries, services, and tools to
help you build, grow, and monetize your app. Learn more about Firebase at the
[official Firebase website](https://firebase.google.com).

## Installation

See the subsections below for details about the different installation methods.
Where available, it's recommended to install libraries with a `Swift` suffix to
get the best experience when writing your app in Swift.

- [Swift Package Manager](#swift-package-manager-installation)
- [CocoaPods](#cocoapods-installation)
- [Install from GitHub](#install-from-github)
- [Experimental Carthage](#carthage-ios-only)
- [Framework or library](#use-firebase-from-a-framework-or-a-library)

### Swift Package Manager installation

Find instructions for installing using
[Swift Package Manager](https://swift.org/package-manager/) in the
[Firebase get started documentation](https://firebase.google.com/docs/ios/setup).

### CocoaPods installation

Find instructions for installing with CocoaPods (`pod install`) in the
[Firebase installation options documentation](https://firebase.google.com/docs/ios/installation-methods#cocoapods).

**Note:** To accommodate the read-only announcement from CocoaPods, Firebase
will stop publishing new versions to CocoaPods in October 2026.
[Learn more.](https://firebase.google.com/docs/ios/cocoapods-deprecation)

### Install from GitHub

You can install from GitHub to access the Firebase repo at other branches, tags,
or commits.

#### Background

For instructions and options about overriding pod source locations, see the
[Podfile Syntax Reference](https://guides.cocoapods.org/syntax/podfile.html#pod).

#### Access Firebase source snapshots

All official releases are tagged in this repo and available via CocoaPods. To
access a local source snapshot or unreleased branch, use Podfile directives.
Here are some example directives which use `FirebaseFirestore` as the example
library.

To access `FirebaseFirestore` via a **branch**:

```ruby
pod 'FirebaseCore', :git => 'https://github.com/firebase/firebase-ios-sdk.git', :branch => 'main'
pod 'FirebaseFirestore', :git => 'https://github.com/firebase/firebase-ios-sdk.git', :branch => 'main'
```

To access `FirebaseFirestore` via a **checked-out version** of the `firebase-ios-sdk` repo:

```ruby
pod 'FirebaseCore', :path => '/path/to/firebase-ios-sdk'
pod 'FirebaseFirestore', :path => '/path/to/firebase-ios-sdk'
```

### Carthage (iOS only)

Find instructions for the experimental Carthage distribution (iOS only) at
[Carthage.md](Carthage.md) within this repo.

### Use Firebase from a Framework or a library

Find details about using Firebase from a Framework or a library at
[firebase_in_libraries.md](docs/firebase_in_libraries.md) within this repo.

## Development

To develop Firebase software in this repository, make sure that you have at
minimum the following software:

- Xcode 26.2 (or later)

### Development options

CocoaPods is still the canonical way to develop, but much of the repo now
supports development with Swift Package Manager.

- [CocoaPods](#development-using-cocoapods)
- [Swift Package Manager](#development-using-swift-package-manager)

#### Development using CocoaPods

Install the following:

- CocoaPods 1.12.0 (or later)
- [CocoaPods generate](https://github.com/square/cocoapods-generate)

Run the following for the pod that you want to develop:

```ruby
pod gen Firebase{name here}.podspec --local-sources=./ --auto-open --platforms=ios
```

Note the following:

- If the CocoaPods cache is out of date, you may need to run `pod repo update`
  before the `pod gen` command.

- Set the `--platforms` option to `macos` or `tvos` to develop or test for those
  platforms. Since 10.2, Xcode does not properly handle multi-platform
  CocoaPods workspaces.

- Firestore has a self-contained Xcode project. For details, see
  [Firestore/README](Firestore/README.md) within this repo.

##### Development for Catalyst

1.  Run `pod gen {name here}.podspec --local-sources=./ --auto-open --platforms=ios`
2.  Check the Mac box in the App-iOS Build Settings.
3.  Sign the App in the _Settings Signing & Capabilities_ tab.
4.  Click _Pods_ in the Project Manager.
5.  Add Signing to the iOS host app and unit test targets.
6.  Select the Unit-unit scheme.
7.  Run it to build and test.

Alternatively, disable signing in each target:

1.  Go to the _Build Settings_ tab.
2.  Click `+`.
3.  Select `Add User-Defined Setting`.
4.  Add the `CODE_SIGNING_REQUIRED` setting with a value of `NO`.

#### Development using Swift Package Manager

1.  Enable test schemes: `./scripts/setup_spm_tests.sh`
2.  Run `open Package.swift` or double-click `Package.swift` in Finder.
3.  Xcode will open the project. Choose one of the following:
    - Choose a scheme for a library to build or test suite to run.
    - Choose a target platform by selecting the run destination along with the scheme.

### Additional development information

#### Add a new Firebase pod

For information about adding a new Firebase pod, see
[AddNewPod.md](docs/AddNewPod.md) within this repo.

#### Manage headers and imports

For information about managing headers and imports, see
[HeadersImports](HeadersImports.md) within this repo.

#### Code formatting

To ensure that the code is formatted consistently, run the script
[./scripts/check.sh](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/check.sh)
before creating a pull request (PR).

GitHub Actions will verify that any code changes are done in a style-compliant
way. Install `clang-format` and `mint`:

```console
brew install clang-format@22
brew install mint
```

#### Run unit tests

Select a scheme and press Command-u to build a component and run its unit tests.

#### Run sample apps

To run the sample apps and integration tests, you'll need a valid
`GoogleService-Info.plist` file. The Firebase Xcode project contains dummy plist
files without real values, but they can be replaced with real plist files. To
get your own `GoogleService-Info.plist` files:

1.  Go to the [Firebase console](https://console.firebase.google.com/).
2.  Create a new Firebase project, if you don't already have one.
3.  For each sample app you want to test, create a new Firebase app with the
    sample app's bundle identifier (e.g., `com.google.Database-Example`).
4.  Download the resulting `GoogleService-Info.plist` and add it to the Xcode
    project.

#### Generate coverage reports

For instructions about generating coverage reports, see
[scripts/code_coverage_report/README](scripts/code_coverage_report/README.md)
within this repo.

## Special instructions for specific libraries

The sections below describe special instructions for specific Firebase
libraries.

### Firebase AI Logic

See the [Firebase AI Logic README](FirebaseAI#development) for instructions
about building and testing the SDK.

### Firebase Auth

See the [Auth Sample README](FirebaseAuth/Tests/Sample/README.md) for
instructions about building and running the `FirebaseAuth` pod along with
various samples and tests.

### Firebase Cloud Messaging - FCM (push notifications)

Push notifications can only be delivered to specially provisioned App IDs in the
developer portal. Here's how to test receiving push notifications:

1.  Change the bundle identifier of the sample app to something you own in your
    Apple Developer account and enable that App ID for push notifications.
2.  [Upload your APNs Provider Authentication Key or certificate to the Firebase console](https://firebase.google.com/docs/cloud-messaging/ios/certs)
    at **Project Settings > Cloud Messaging > [Your Firebase App]**.
3.  Make sure your iOS device is added to your Apple Developer portal as a test
    device.

**Note:** The iOS simulator cannot register for remote notifications and will
not receive push notifications. To receive push notifications, follow the steps
above and run the app on a physical device.

### Firebase Database (Realtime Database)

The `FirebaseDatabase` integration tests can be run against a locally running
Database Emulator or against a production instance.

- To run against a local emulator instance, invoke
  `./scripts/run_database_emulator.sh start` _before_ running the integration
  test.

- To run against a production instance, provide a valid
  `GoogleServices-Info.plist` and copy it to
  `FirebaseDatabase/Tests/Resources/GoogleService-Info.plist`.\
  Your Firebase Security Rules must be set to
  [public](https://firebase.google.com/docs/database/security/quickstart) while
  your tests are running, but make sure to publish production-grade Security
  Rules before making your app public.

### Firebase Dynamic Links

Firebase Dynamic Links is **deprecated** and should not be used in new projects.
The service will shut down on August 25, 2025.

For more guidance, see our
[Dynamic Links Deprecation FAQ documentation](https://firebase.google.com/support/dynamic-links-faq).

### Firebase Performance Monitoring

See the [Performance README](FirebasePerformance/README.md) for instructions
about building the SDK. See the
[Performance TestApp README](FirebasePerformance/Tests/TestApp/README.md)
for instructions about integrating Performance with the dev test app.

### Firebase Storage

To run the Storage integration tests, follow the instructions in
[StorageIntegration.swift](FirebaseStorage/Tests/Integration/StorageIntegration.swift).

## Building with Firebase on Apple platforms

Firebase provides official beta support for macOS, Catalyst, and tvOS. visionOS,
and watchOS are community supported. Thanks to community contributions for many
of the multi-platform PRs.

At this time, most Firebase products are available across Apple platforms. There
are still a few gaps, especially on visionOS and watchOS. For details about the
current support matrix, see
[this chart](https://firebase.google.com/docs/ios/learn-more#firebase_library_support_by_platform)
in the Firebase documentation.

### visionOS

Where supported, visionOS works as expected with the exception of Firestore via
Swift Package Manager where it is required to use the source distribution.

To enable the Firestore source distribution, quit Xcode and open the desired
project from the command line with the `FIREBASE_SOURCE_FIRESTORE` environment
variable: `open --env FIREBASE_SOURCE_FIRESTORE /path/to/project.xcodeproj`.
To go back to using the binary distribution of Firestore, quit Xcode and open
Xcode like normal, without the environment variable.

### watchOS

Thanks to contributions from the community, many of Firebase SDKs now compile,
run unit tests, and work on watchOS. See the
[Independent Watch App Sample](Example/watchOSSample).

Keep in mind that watchOS is not officially supported by Firebase. While we can
catch basic unit test issues with GitHub Actions, there may be some changes
where the SDK no longer works as expected on watchOS. If you encounter this,
please [file an issue](https://github.com/firebase/firebase-ios-sdk/issues).

During app setup in the console, you may get to a step that mentions something
like "Checking if the app has communicated with our servers". This relies on
`FirebaseAnalytics` and will not work on watchOS.
**It's safe to ignore the message and continue**, the rest of the SDKs will work
as expected.

#### Additional Crashlytics notes for watchOS

Using Crashlytics with watchOS has limited support. Due to watchOS restrictions,
mach exceptions and signal crashes are not recorded. (Crashes in SwiftUI are
generated as mach exceptions, so will not be recorded).

## Combine

Thanks to contributions from the community, _FirebaseCombineSwift_ contains
support for Apple's Combine framework. This module is currently under
development and not yet supported for use in production environments. For more
details, see the [docs](FirebaseCombineSwift/README.md) within this repo.

## Roadmap

See [Roadmap](ROADMAP.md) for more about the Firebase Apple SDK Open Source
plans and directions.

## Contributing

See [Contributing](CONTRIBUTING.md) for more information on contributing to the
Firebase Apple SDK.

## License

The contents of this repository are licensed under the
[Apache License, version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Your use of Firebase is governed by the
[Terms of Service for Firebase Services](https://firebase.google.com/terms/).