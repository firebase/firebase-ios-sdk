# Firebase Apple SDK Roadmap

## Contributing

This is a longer roadmap than we can implement internally and we very
much welcome community contributions. If you're interested, please indicate it
via an issue or PR.

See the information about Development setup [here](README.md#Development) and
[Contributing](CONTRIBUTING.md) for more information on the mechanics of
contributing to the Firebase iOS SDK.

## More Swifty

### APIs

Continue to evolve the Firebase API surface to be more
Swift-friendly. This is generally done with Swift specific extension libraries.

[FirebaseStorageSwift](FirebaseStorageSwift) is an example that extends
FirebaseStorage with APIs that take advantage of Swift's Result type.
[FirebaseFirestoreSwift](Firestore/Swift) is a larger library that adds
Codable support for Firestore.

Add more such APIs to improve the Firebase Swift API.

More details in the
[project](https://github.com/firebase/firebase-ios-sdk/projects/2).

### Combine

Add combine support for Firebase. See Tracking Bug at #7295 and
[Project](https://github.com/firebase/firebase-ios-sdk/projects/3).

## More complete Apple platform support

Continue to expand the range and quality of Firebase support across
all Apple platforms.

Expand the
[current non-iOS platform support](README.md#community-supported-efforts)
from community supported to officially supported.

Fill in the missing pieces of the support matrix, which is
primarily *watchOS* for several libraries.

## Getting Started

### Quickstarts

Modernize the [Swift Quickstarts](https://github.com/firebase/quickstart-ios).
Continue the work done in 2020 that was done for
[Analytics](https://github.com/firebase/quickstart-ios/tree/master/analytics),
[Auth](https://github.com/firebase/quickstart-ios/tree/master/authentication),
and
[RemoteConfig](https://github.com/firebase/quickstart-ios/tree/master/config) to
use modern Swift and support multiple Apple platforms.

## Other

Check out the [issue list](https://github.com/firebase/firebase-ios-sdk/issues).
Indicate your interest for a bug fix or feature request with a thumbs-up or a
comment indicating your interest in making a contribution.

If you don't see the feature you're looking for, please add a
[Feature Request](https://github.com/firebase/firebase-ios-sdk/issues/new/choose).
