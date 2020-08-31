# Swift Package Manager for Firebase **Beta**

## Introduction

Starting with the 6.31.0 release, Firebase supports installation via [Swift
Package Manager](https://swift.org/package-manager/) in Beta status.


## Limitations

- Requires at least Xcode 12 beta 4.
- SwiftUI Previews require Xcode 12 beta 5.
- Analytics requires clients to add `-ObjC` linker option.
- Analytics is only supported for iOS and cannot be used in apps that support other platforms.
- Messaging, Performance, Firebase ML, and App Distribution are not initially available.
- watchOS support is not initially available.

## Installation

If you've previously used CocoaPods, remove them from the project with `pod deintegrate`.

Install Firebase via Swift Package Manager:

<img src="docs/resources/SPMAddPackage.png">

Select the Firebase GitHub repository - `https://github.com/firebase/firebase-ios-sdk.git`:

<img src="docs/resources/SPMChoose.png">

Select the beta branch.

Note: Starting with the 6.31.0 release, the versions are specified
in a format like 6.31-spm-beta. We won't support standard repository
versioning until later in the beta or with general availability of the SPM
distribution.

<img src="docs/resources/SPMSelect.png">

Choose the Firebase products that you want installed in your app. (Note, before
6.32-spm-beta, the Firebase product should also be selected.)

<img src="docs/resources/SPMProducts.png">

If you've installed FirebaseAnalytics, Add the `-ObjC` option to `Other Linker Flags`
in the `Build Settings` tab.

<img src="docs/resources/SPMObjC.png">

## Questions and Issues

Please provide any feedback via a [GitHub
Issue](https://github.com/firebase/firebase-ios-sdk/issues/new?template=bug_report.md).

See current open Swift Package Manager issues
[here](https://github.com/firebase/firebase-ios-sdk/labels/Swift%20Package%20Manager).
