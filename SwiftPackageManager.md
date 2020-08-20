# Swift Package Manager for Firebase **Beta**

## Introduction

Starting with the 6.31.0 release, Firebase supports installation via [Swift
Package Manager](https://swift.org/package-manager/) in Beta status.


## Limitations

- Requires at least Xcode 12 beta 4.
- SwiftUI Previews require Xcode 12 beta 5.
- Analytics requires clients to add -ObjC linker option.
- Messaging, Performance, Firebase ML, and App Distribution are not initiallly available.
- watchOS support is not initially available.

## Installation

If you've previously used CocoaPods, remove them from the project with `pod deintegrate`.

Install Firebase via Swift Package Manager:

<img src="docs/resources/SPMAddPackage.png">

Select the Firebase GitHub repository:

<img src="docs/resources/SPMChoose.png">

Select the beta branch. 

Note: Starting with the 6.31.0 release, the versions are specified
in a format like 6.31-spm-beta. We won't support standard repository
versioning until later in the beta or with general availability of the SPM
distribution.

<img src="docs/resources/SPMSelect.png">

Choose the Firebase product and any additional products that you want installed
in your app.

<img src="docs/resources/SPMChoose.png">

If you've installed FirebaseAnalytics, Add the -ObjC option to `Other Linker Flags`
in the `Build Settings` tab.

<img src="docs/resources/SPMObjC.png">

## Questions and Issues

Please provide any feedback via a [GitHub 
Issue](https://github.com/firebase/firebase-ios-sdk/issues/new?template=bug_report.md).

See current open Swift Package Manager issues
[here](https://github.com/firebase/firebase-ios-sdk/labels/Swift%20Package%20Manager).
