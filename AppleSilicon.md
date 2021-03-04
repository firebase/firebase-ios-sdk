# Apple Silicon Simulator Support

If you're using Swift Package Manager or the zip file, everything should work for you
using Xcode 12.0 or above. See the instructions below for CocoaPods and Carthage.

## CocoaPods

Starting with Firebase 7.5.0, Firebase supports Apple Silicon Macs via CocoaPods. *CocoaPods 1.10.0
is required.*

The special `M1` versions required for FirebaseAnalytics support for versions 7.2.0 through 7.4.0
are no longer necessary.

## Carthage

XCFrameworks are required to include the arm64 slice for iOS devices and the macOS simulator for
Macs running on Apple silicon. Unfortunately, Carthage does not support XCFrameworks yet which
prevents us from being able to include support. See
[Carthage/Carthage#2799](https://github.com/Carthage/Carthage/issues/2799) for progress.
