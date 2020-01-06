# Adding a New Firebase CocoaPod

## Introduction

The Firebase build is driven by the contents of a podspec. It is helpful to
use an existing podspec as a template when starting a new pod.

## Podspec attributes

See the [Podspec Syntax Reference](https://guides.cocoapods.org/syntax/podspec.html) for
detailed instructions. Some Firebase specific guidance below:

* `s.deployment_target` - Ideally should include ios, osx, and tvos. See
[FirebaseCore.podspec](FirebaseCore.podspec) for the current Firebase minimum version settings.

* `s.static_framework` - By default, Firebase pods should be static frameworks.

* `s.dependency` - Dependencies on other Firebase pods should allow minor version updates -
like `s.dependency 'FirebaseCore', '~> 6.0'`

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
