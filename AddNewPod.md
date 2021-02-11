# Adding a New Firebase CocoaPod

## Introduction

The Firebase build is driven by the contents of a podspec. It is helpful to
use an existing podspec as a template when starting a new pod.

## Podspec attributes

See the [Podspec Syntax Reference](https://guides.cocoapods.org/syntax/podspec.html) for
detailed instructions. Some Firebase specific guidance below:

* `s.deployment_target` - Ideally should include ios, osx, and tvos. See
[FirebaseCore.podspec](FirebaseCore.podspec) for the current Firebase minimum version settings.

* `s.dependency` - Dependencies on other Firebase pods and pods in this repo should specify a
version and allow minor version updates - like `s.dependency 'FirebaseCore', '~> 6.6'`. When
initially defined, choose the most recently released minor version of the dependency.

* `s.pod_target_xcconfig` - Add any specific build settings.
  * For portability, any Firebase
pod with other Firebase dependencies should build for c99 -
`'GCC_C_LANGUAGE_STANDARD' => 'c99'`.
  * The pod's version should be passed in as a #define
for FIRComponent registration. See examples of setting `GCC_PREPROCESSOR_DEFINITIONS`.
  * All imports (outside of Public headers) should be repo relative -
    `'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}"'`.

* `s.test_spec` should be used for defining all unit and integration test suites.


## Directory Structure

The Firebase library `Foo` should be defined in `FirebaseFoo.podspec`. All of its
contents should be in the `FirebaseFoo` directory.

* `FirebaseFoo/Sources` - All source. Directory structure is up to the library owner. Any code from a
non-Google open source project should be nested under a `third_party` directory.
* `FirebaseFoo/Sources/Public` - Public Headers.
* `FirebaseFoo/Sources/Private` - Private Headers (headers not part of public API, but available for
explicit import by other Firebase pods)
* `FirebaseFoo/Tests/Unit` - Required (If the library only has unit tests, `Unit` can be omitted.)
* `FirebaseFoo/Tests/Integration` - Encouraged
* `FirebaseFoo/Tests/Sample` - Optional
* `FirebaseFoo/Tests/{Other}` - Optional

## Headers and Imports

See [Headers and Imports](HeadersImports.md) for details on managing headers and imports.

## Continous Integration

Set up a GitHub Action workflow for the pod. A good example template is
[storage.yml](.github/workflows/storage.yml).

All code should comply with Objective-C and Swift style requirements and successfully pass
the GitHub Action check phase. Run [scripts/style.sh](scripts/style.sh).

## GitHub Infrastructure

For GitHub tag management and public header change detection, add a GitHub api tag and update
[Dangerfile](Dangerfile).

## Firebase Integration

For top-level Firebase pods that map to documented products:

* Make sure the public umbrella header is imported via [Firebase.h](CoreOnly/Sources/Firebase.h)
  wrapped in `__has_include`. Follow the existing examples for details.
* Update [Firebase.podspec](Firebase.podspec).
* Register library via registerInternalLibrary API like this
  [Storage example](FirebaseStorage/Sources/FIRStorageComponent.m).
* When ready to release with Firebase, add to the
  [Firebase manifest](ReleaseTooling/Sources/FirebaseManifest/FirebaseManifest.swift).
* Add a [quickstart](https://github.com/firebase/quickstart-ios).

## Review and Release

* Contact icore-eng@ at least a month in advance of desired release date to coordinate the
  initial launch plan.
