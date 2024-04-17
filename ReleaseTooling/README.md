# Firebase Release Tools

This project includes Firebase release tooling including a zip builder and a
Firebase release candidate creation tool.

The rest of this file documents using the `zip-builder` tool. Information about the rest of the
tools for managing Firebase releases and information about developing these tools is at
[DEVELOP.md](DEVELOP.md)

## Zip Builder

The `zip-builder` tool generates a zip distribution of binary `.xcframeworks` from an input set of
CocoaPods.

### Requirements

In order to build the Zip file, you will need:

- Xcode 12.2
- CocoaPods
- An internet connection to fetch CocoaPods

### Running the Tool

You can run the tool with `swift run zip-builder [ARGS]` or `open Package.swift` to debug or run
within Xcode.

Since Apple does not support linking libraries built by future Xcode versions, make sure to build with the
earliest Xcode needed by any of the library clients. The Xcode command line tools must also be configured
for that version. Check with `xcodebuild -version`.

### Launch Arguments

See `main.swift`  for information on specific launch arguments,  or use  `swift run zip-builder --help`.

You can pass in launch arguments with Xcode by clicking "zip-builder" beside the Run/Stop buttons, clicking
"Edit Scheme" and adding them in the "Arguments Passed On Launch" section.

#### Common Arguments

Use `--pods <pods>` to specify the CocoaPods to build.

The `pods` option will choose whatever pods get installed from an unversioned CocoaPods install,
typically the latest versions.

To explicitly specify the CocoaPods versions, use a JSON specification :
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

Other optional arguments:
- `--no-update-pod-repo`
  - This is for speedups when `pod repo update` has already been run recently.
- `--minimum-ios-version <minimum-ios-version>`
  - Change the minimum iOS version from the default of 10.
- `--output-dir <output-dir>`
  - The directory to copy the built Zip file. If this is not set, the path to the Zip file will
  be logged to the console.
- `--keep-build-artifacts`
  - Keep the build artifacts.
