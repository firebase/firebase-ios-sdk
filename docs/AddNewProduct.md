# Adding a New Firebase Product Apple SDK

## Introduction

This document provides guidance on many of the factors to consider when designing and developing
a new Firebase Product Apple SDK. The list is not totally comprehensive and there is ongoing
evolution, so you should also consult with the iCore team as you are ramping up.

## Swift

While much of Firebase has been implemented in Objective-C, any new products or major
implementations should be implemented in Swift. If Objective-C API support is required it should
be implemented via the Swift `@objc` attribute. Consult with iCore and product management about
the requirement itself.

Apple and others provide many great guides for Swift programming. Googlers, see also
[go/swift-sdks-2022](http://go/swift-sdks-2022).

Existing Firebase Swift implementations can be helpful. However, note that they are mostly
Objective-C ports and do not take advantage of Swift features like structs, default arguments, and
async/await as much as new implementations should.

### Swift APIs

[Apple's API design guidelines](https://www.swift.org/documentation/api-design-guidelines/)

### Swift Style

Follow this [Style Guide](https://google.github.io/swift/).

Firebase uses [swiftformat](https://github.com/nicklockwood/SwiftFormat) for enforcing code
formatting consistency.

## Package Managers

Firebase supports four different distributions - Swift Package Manager, CocoaPods, Carthage, and
binary zip distributions.

Firebase SDKs can be developed via Swift Package Manager or CocoaPods.

The new project should set up a `podspec` for CocoaPods and add a `product` specification to
the [Package.swift](Package.swift).

## Testing

All Firebase code should be unit tested. Ideally, the unit tests should be driven from both
CocoaPods and Swift Package Manager. If only one is implemented, it should be SPM.

## Dependencies

Dependencies are a great way to add libraries of well-tested functionality to Firebase. On the flip
side, they can add bloat and risk to the Firebase user experience. Ideally, only existing Firebase
dependencies should be used. See [Package.swift](Package.swift). If a new dependency is needed,
consider making it a weak dependency, implemented with a direct dependency on a protocol instead of
the full library. New non-protocol-only direct dependencies must be approved by the iCore team.

## Directory Structure

The Firebase library `Foo` should be defined in `FirebaseFoo.podspec`. All of its
contents should be in the `FirebaseFoo` directory.

* `FirebaseFoo/Sources` - All source. Directory structure is up to the library owner. Any code from a
non-Google open source project should be nested under a `third_party` directory.
* `FirebaseFoo/Tests/Unit` - Required (If the library only has unit tests, `Unit` can be omitted.)
* `FirebaseFoo/Tests/Integration` - Encouraged
* `FirebaseFoo/Tests/Sample` - Optional
* `FirebaseFoo/Tests/{Other}` - Optional

## Continuous Integration

Set up a GitHub Action workflow for the pod. A good example template is
[storage.yml](.github/workflows/storage.yml).

All code should comply with Objective-C and Swift style requirements and successfully pass
the GitHub Action check phase. Run [scripts/style.sh](scripts/style.sh).

## GitHub Infrastructure

For GitHub tag management and public header change detection, add a GitHub api tag and update
[Dangerfile](Dangerfile).

## Firebase Integration

For top-level Firebase pods that map to documented products:

* Update [Firebase.podspec](Firebase.podspec).
* Register Swift library by creating a component like
  [Functions example](FirebaseFunctions/Sources/Internal/FunctionsComponent.swift) and
  detecting it in `registerSwiftComponents` in
  [FIRApp.m](FirebaseCore/Sources/FIRApp.m).
* When ready to release with Firebase, add to the
  [Firebase manifest](ReleaseTooling/Sources/FirebaseManifest/FirebaseManifest.swift).
* Create an empty JSON file to enable the Carthage build
  [here](ReleaseTooling/Sources/CarthageJSON).
* Add a [quickstart](https://github.com/firebase/quickstart-ios).

## Review and Release

* Contact icore-eng@ at least a month in advance of desired release date to coordinate the
  initial launch plan.
