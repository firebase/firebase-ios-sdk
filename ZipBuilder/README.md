# Firebase Zip File Builder

This project builds the Firebase iOS Zip file for distribution.

## Overview

This is a small Swift Package Manager project that allows users to package a Firebase iOS Zip file. With no launch
arguments, it will use the most recent public versions of all SDKs included in the zip file.

It was designed to fail fast with an explanation of what went wrong, so you can fix issues or dig in without having to dig
too deep into the code.

## Requirements

In order to build the Zip file, you will need:

- Xcode 10.1
- CocoaPods
- An internet connection to fetch CocoaPods

## Running the Tool

You can run the tool with `swift run ZipBuilder [ARGS]` or generate an Xcode project with
`swift package generate-xcodeproj` and run within Xcode.

In the near future, releases will be built via a builder server instead of on the release engineer's machine, making these
instructions more of a reference to understand what's going on instead of how to build it yourself.

## Launch Arguments

See `main.swift` and the `LaunchArgs` struct for information on specific launch arguments.

You can pass in launch arguments with Xcode by clicking "ZipBuilder" beside the Run/Stop buttons, clicking "Edit
Scheme" and adding them in the "Arguments Passed On Launch" section.

### Common Arguments

These arguments assume you're running the command from the `ZipBuilder` directory.

**Required** arguments:
- `-templateDir $(pwd)/Template`
  - This should always be the same.
- `-coreDiagnosticsDir <PATH_TO_FirebaseCoreDiagnostics.framework>`
  - Needed to overwrite the existing Core Diagnostics framework.

Optional comon arguments:
- `-updatePodRepo false`
  - This is for speedups when `pod repo update` has already been run recently.

For release engineers (Googlers packaging an upcoming Firebase release) these commands should also be used:
-  `-customSpecRepos sso://cpdc-internal/firebase`
  - This pulls the latest podspecs from the CocoaPods staging area.
- `-releasingSDKs <PATH_TO_current.textproto>` and
- `-existingVersions <PATH_TO_all_firebase_ios_sdks.textproto>`
  - Validates the version numbers fetched from CocoaPods staging against the expected released versions from these
    textprotos.

Putting them all together, here's a common command to build a releaseable Zip file:

```
swift run ZipBuilder -templateDir $(pwd)/Template -updatePodRepo false \
-coreDiagnosticsDir /private/tmp/tmpUqBxKN/FirebaseCoreDiagnostics.framework \
-releasingSDKs <PATH_TO_current.textproto> \
-existingVersions <PATH_TO_all_firebase_ios_sdks.textproto> \
-customSpecRepos sso://cpdc-internal/firebase
```

## Debugging

You can generate an Xcode project for the tool by running `swift package generate-xcodeproj` in this directory.
See the above instructions for adding Launch Arguments to the Xcode build.

## Priorities

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
