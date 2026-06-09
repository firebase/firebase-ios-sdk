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

> [!WARNING]
> **CocoaPods:** New versions of the Firebase Apple SDK will no longer be
> published to CocoaPods after **October 2026**. Existing CocoaPods versions
> will remain available and installations will remain functional. See the
> [migration guide](https://firebase.google.com/docs/ios/cocoapods-deprecation)
> for more information.

> [!IMPORTANT]
> ***Preview Release: Firebase AI Logic's Gemini Foundation Models framework adaptor is now available in preview. Get started by visiting the [documentation](https://firebase.google.com/docs/ai-logic/apple-foundation-models-framework/get-started).***

# Firebase Apple Open Source Development

This repository contains the source code for all Apple platform Firebase
libraries except `FirebaseAnalytics`.

Firebase is an app development platform with libraries, services, and tools to
help you build, grow, and monetize your app. Learn more about Firebase at the
[official Firebase website](https://firebase.google.com).

### Supported Firebase Products

The following products are open-source and included in this repository:

*   [Firebase AI Logic](https://firebase.google.com/docs/ai-logic) (`FirebaseAI`)
*   [App Check](https://firebase.google.com/docs/app-check) (`FirebaseAppCheck`)
*   [App Distribution](https://firebase.google.com/docs/app-distribution) (`FirebaseAppDistribution`)
*   [Authentication](https://firebase.google.com/docs/auth) (`FirebaseAuth`)
*   [Cloud Firestore](https://firebase.google.com/docs/firestore) (`FirebaseFirestore`)
*   [Cloud Functions](https://firebase.google.com/docs/functions) (`FirebaseFunctions`)
*   [Cloud Messaging](https://firebase.google.com/docs/cloud-messaging) (`FirebaseMessaging`)
*   [Crashlytics](https://firebase.google.com/docs/crashlytics) (`FirebaseCrashlytics`)
*   [In-App Messaging](https://firebase.google.com/docs/in-app-messaging) (`FirebaseInAppMessaging`)
*   [Performance Monitoring](https://firebase.google.com/docs/perf-mon) (`FirebasePerformance`)
*   [Realtime Database](https://firebase.google.com/docs/database) (`FirebaseDatabase`)
*   [Remote Config](https://firebase.google.com/docs/remote-config) (`FirebaseRemoteConfig`)
*   [Storage](https://firebase.google.com/docs/storage) (`FirebaseStorage`)

> [!NOTE]
> **Firebase Analytics** is not open-source, but its pre-compiled binaries are
> included when installing Firebase via Swift Package Manager or CocoaPods.

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


## Building with Firebase on Apple platforms

Firebase provides official beta support for macOS, Catalyst, and tvOS. visionOS
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

For information on how to contribute, set up the development environment, build,
or test the SDK, see the [Contributing Guide](CONTRIBUTING.md).

## License

The contents of this repository are licensed under the
[Apache License, version 2.0](http://www.apache.org/licenses/LICENSE-2.0).

Your use of Firebase is governed by the
[Terms of Service for Firebase Services](https://firebase.google.com/terms/).
