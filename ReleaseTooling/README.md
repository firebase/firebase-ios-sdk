# Firebase Release Tools

This project includes Firebase release tooling including a zip builder and a
Firebase release candidate creation tool.

The tools are designed to fail fast with an explanation of what went wrong, so
you can fix issues or dig in without having to dig too deep into the code.

## Zip Builder

This is a Swift Package Manager project that allows users to package an iOS Zip file of binary
packages.

### Requirements

In order to build the Zip file, you will need:

- Xcode 11.0
- CocoaPods
- An internet connection to fetch CocoaPods

### Running the Tool

You can run the tool with `swift run zip-builder [ARGS]` or generate an Xcode project with
`swift package generate-xcodeproj` and run within Xcode.

Since Apple does not support linking libraries built by future Xcode versions, make sure to builid with the
earliest Xcode needed by any of the library clients. The Xcode command line tools must also be configured
for that version. Check with `xcodebuild -version`.

### Launch Arguments

See `main.swift`  for information on specific launch arguments,  or use  `swift run zip-builder --help`.

You can pass in launch arguments with Xcode by clicking "zip-builder" beside the Run/Stop buttons, clicking
"Edit Scheme" and adding them in the "Arguments Passed On Launch" section.

#### Common Arguments

These arguments assume you're running the command from the `ReleaseTooling` directory.

**Required** arguments:

- `--repo-dir <PATH_TO_firebase_ios_sdk_REPO>`
  - The root of the `firebase-ios-sdk` repo.

Typical argument (all use cases except Firebase release build):
- `--zip-pods <PATH_TO.json>`
  - This is a JSON list of the pods to consolidate into a zip of binary frameworks. For example,

```
[
  {
    "name": "GoogleDataTransport",
    "version" : "3.2.0"
  },
  {
    "name": "FirebaseMessaging"
  }
]
```

Indicates to install the version 3.2.0 of "GoogleDataTransport" and the latest
version of "FirebaseMessaging". The version string is optional and can be any
valid [CocoaPods Podfile version specifier](https://guides.cocoapods.org/syntax/podfile.html#pod).


Optional common arguments:
- `--no-update-pod-repo`
  - This is for speedups when `pod repo update` has already been run recently.

For release engineers (Googlers packaging an upcoming Firebase release) these commands should also be used:
-  `--custom-spec-repos sso://cpdc-internal/firebase`
  - This pulls the latest podspecs from the CocoaPods staging area.
- `--repo-dir path` GitHub repo containing Template and Carthage json file inputs.
- `--enable-carthage-build` Turns on generation of Carthage zips and json file updates.
- `--keep-build-artifacts` Useful for debugging and verifying the zip build contents.

Putting them all together, here's a common command to build a releaseable Zip file:

```
swift run zip-builder --update-pod-repo \
--repo-dir <PATH_TO_current.firebase_ios_sdk.repo> \
--custom-spec-repos sso://cpdc-internal/firebase \
--enable-carthage-build \
--keep-build-artifacts
```

### Carthage

Carthage binaries can also be built at the same time as the zip file by passing in `--enable-carthage-build`
as a command line argument. This directory should contain JSON files describing versions and download
locations for each product. This will result in a folder called "carthage" at the root where the zip directory exists
containing all the zip files and JSON files necessary for distribution.

## Firebase Releaser

Provides several functions for staging a Firebase release candidate. See the internal go/firi link
for the process documentation.

### Launch Arguments

See `main.swift`  for information on specific launch arguments.

You can pass in launch arguments with Xcode by selecting the  "firebase-releaser" scheme
beside the Run/Stop buttons, clicking "Edit Scheme" and adding them in the "Arguments Passed On Launch"
section.

## Development Philosophy

The following section describes the priorities taken while building this tool and should be followed
for any modifications.

### Readable and Maintainable
This code will rarely be modified outside of bug fixes, but read very frequently. There should be no
"magic lines" that do multiple things. Verbosity is preferred over making the code shorter and
performing multiple actions at once. All functions should be well documented.

### Avoid Calling bash Commands Where Possible
Instead of using `cat`, `find`, `grep`, or `perl` use `String` APIs to read the contents of a file,
`FileManager` to properly list contents of a directory, `RegularExpression` for pattern matching,
etc. If there's a `Foundation` API available, it should be used.

### Understandable Output
The output of the script should make it immediately obvious if there were any issues and exactly
what those issues were, without looking at the code. It should also be very clear if the Zip file
was properly built and output the file location.

### Show Xcode and API Output on Failures
In the event that there's an Xcode build failure, the logs should be surfaced immediately to aid
debugging. Release engineers should not have to find the Xcode project manually. That being said, a
link to the Xcode project file should be logged as well in case it's necessary. Same goes for errors
logged by exceptions (ex: `FileManager`).

### Testable and Debuggable
Components and functions should be split up in a way that make them easy to test and easy to debug.
Prefer small functions that have proper failure conditions and input validated with `guard`
statements, throwing `fatalError` with a well written error message if it's a critical issue that
prevents the Zip file from being built properly.

### Works from the Command Line or Xcode (Environment Agnostic)
The script should be able to run from the command line to allow for easier automation and Xcode for
simpler debugging and maintenance.

### Any Failure Exits Immediately
The script should not continue if anything necessary for a successful Zip file fails. This includes
things like compiling storyboards, moving resources, missing files, etc. This is to ensure the
integrity of the zip file and that any issues during testing are SDK bugs and not related to the
files and folders.

### Prefer File `URL`s over Strings
Instead of relying on `String`s to represent file paths, use `URL`s as soon as possible to avoid any
missed or double slashes along with other issues.
