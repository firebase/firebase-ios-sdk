# Apple Silicon Simulator Support

If you're using Swift Package Manager or the zip file, everything should work for you
using Xcode 12.0 or above. See the instructions below for CocoaPods and Carthage.

## CocoaPods

All source-based Firebase CocoaPods work as expected. Binary pods are listed below with the current
status.

### Analytics + GoogleAppMeasurement

As of Firebase 7.2.0, FirebaseAnalytics and GoogleAppMeasurement provide a separate distribution of
an XCFramework in order to work around an issue with CocoaPods and static XCFrameworks. This is a
temporary workaround while Analytics is affected by the CocoaPods bug.

When specifying which version of Firebase you'd like in your Podfile, append `-M1` to the version.
See the following examples:

```
# Explicitly require the special `M1` tagged Firebase version, locked to the minor version.
pod 'Firebase/Analytics', '~> 7.2.0-M1'

# Do the same for any other Firebase pod used.
pod 'Firebase/Database', '~> 7.2.0-M1'

# You can also lock on the patch or major versions like so:
pod 'Firebase/Analytics, '7.2.0-M1'
pod 'Firebase/Analytics, '~> 7.2-M1'
```

The CocoaPods issue has been fixed in
[CocoaPods/CocoaPods#10234](https://github.com/CocoaPods/CocoaPods/pull/10234) but has not been
included in a CocoaPods release yet.

### Performance

As of Firebase 7.2.0, FirebasePerformance uses an XCFramework for distribution that works with
Apple silicon.

### FirebaseML

FirebaseML does not yet work with the simulator on Apple silicon Macs.

## Carthage

XCFrameworks are required to include the arm64 slice for iOS devices and the macOS simulator for
Macs running on Apple silicon. Unfortunately, Carthage does not support XCFrameworks yet which
prevents us from being able to include support. See
[Carthage/Carthage#2799](https://github.com/Carthage/Carthage/issues/2799) for progress.

