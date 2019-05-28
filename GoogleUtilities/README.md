# Google Utilities

## Overview

The GoogleUtilities pod is a set of utilities organized into CocoaPods subspecs.
See the [podspec](../GoogleUtilities.podspec) for a summary of what utilities
are currently included. They're used by Firebase and other Google products.

Direct usage by non-Google products and CocoaPods is **NOT** currently
recommended or supported in general.

**However**, we do specifically recommend that non-Google SDKs can use the App Delegate Swizzler to hook into app delegate methods as this reduces conflicts with multiple SDKs trying to do the same.

Instructions on how to adopt the app delegate swizzler for use by your SDK are available [here](./AppDelegateSwizzler/README.md).

## Development

Follow the subsequent instructions to develop, debug, unit test, and
integration test FirebaseFunctions:

### Prereqs

- At least CocoaPods 1.7.0

### To Develop

- Run `pod gen GoogleUtilities.podspec`
- `open gen/GoogleUtilities/GoogleUtilities.xcworkspace`

OR these two commands can be combined with

- `pod gen GoogleUtilities.podspec --auto-open --gen-directory="gen" --clean`

You're now in an Xcode workspace generate for building, debugging and
testing the GoogleUtilities CocoaPod.

### Running Unit Tests

Choose the one of the Tests* schemes and press Command-u.
