# Firebase iOS SDK Open Source Roadmap

## More Open Source

The Firebase team plans to open source more of Firebase components.

## Build Improvements

Even though they're built from the same source, the FirebaseCommunity CocoaPod
is not currently interoperable with the Firebase CocoaPod.

This is because CocoaPods does not support interdepencies between open source
and closed source static library CocoaPods.

We'd like to work with CocoaPods to add this capability and update Firebase
build accordingly. See this
[CocoaPods Pull Request](https://github.com/CocoaPods/CocoaPods/pull/6811).

## Continuous Integration

* [Stabilize Travis](https://github.com/firebase/firebase-ios-sdk/issues/102)
* [Verify Objective-C style guide compliance](https://github.com/firebase/firebase-ios-sdk/issues/103)

## Samples and Integration Tests

Add more samples to better demonstrate the capabilities of Firebase and help
developers onboard.

## Xcode 9 Workflow

[Ensure Firebase open source development works well with Xcode 9's git and
GitHub features](https://github.com/firebase/firebase-ios-sdk/issues/101).

## Other

Check out the [issue list](https://github.com/firebase/firebase-ios-sdk/issues)
to see more detail about plans and desires.

If you don't see the feature you're looking for, please add a
[Feature Request](https://github.com/firebase/firebase-ios-sdk/issues/new).

## Contributing

We welcome your participation and contributions! See
[Contributing](CONTRIBUTING.md) for more information on the mechanics of
contributing to the Firebase iOS SDK.
