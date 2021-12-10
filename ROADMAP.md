# Firebase Apple SDK Roadmap

## Contributing

This is a longer roadmap than we can implement internally and we very
much welcome community contributions.

See the information about Development setup [here](README.md#Development) and
[Contributing](CONTRIBUTING.md) for more information on the mechanics of
contributing to the Firebase iOS SDK.

## Modernization - More Swifty

As we go into 2022, it's a top priority for the Firebase team to improve
usability and functionality for Swift developers. We welcome the community's
input and contribution as we work through this.

See the [Project Dashboard](SwiftDashboard.md).

Please upvote existing feature requests, add new feature requests, and send PRs.
* [Example Feature Request](https://github.com/firebase/firebase-ios-sdk/issues/8827)
* [Example Pull Request](https://github.com/firebase/firebase-ios-sdk/pull/6568)

See [Contributing.md](Contributing.md) for full details about contributing
code to the Firebase repo.

Thanks in large part to community contributions, we already have several Swift
improvements:
* Analytics
  * Enabling [SwiftUI Screen tracking](https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseAnalyticsSwift/CHANGELOG.md)
   automated view logging for SwiftUI apps
* Firestore and RTDB
  * Codable Support ([Firestore](https://github.com/firebase/firebase-ios-sdk/pull/3198),
   [Database](https://github.com/firebase/firebase-ios-sdk/tree/master/FirebaseDatabaseSwift/Sources/Codable))
   eliminated manual data processing
  * [Property wrappers](https://github.com/firebase/firebase-ios-sdk/pull/8408) for Firestore collections dramatically simplified client coding
* Storage
  * Eliminated impossible states, provided new and improved async API usage via
   [Result type](https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseStorageSwift/CHANGELOG.md)
   and [async/await](https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseStorageSwift/CHANGELOG.md)
   additions
* ML Model Downloader
  * Full [SDK implementation in Swift](https://github.com/firebase/firebase-ios-sdk/tree/master/FirebaseMLModelDownloader/Sources)
* In App Messaging
  * Vastly simplified usage from SwiftUI with
   [SwiftUI modifiers](https://github.com/firebase/firebase-ios-sdk/pull/7496) to show messages and
   [preview helpers](https://github.com/firebase/firebase-ios-sdk/pull/8351)

### Phase 1 - Address Low Hanging Fruit for all Firebase Products
* Swift API tests
* async/await API evaluation, tests, and augmentation
* Fix non-Swifty APIs
* Fill API gaps
* Better Swift Error Handling
* Property Wrappers (Not necessarily low hanging, but can be high value)
* Identify larger projects for future phases

### APIs

Continue to evolve the Firebase API surface to be more
Swift-friendly. This is generally done with Swift specific extension libraries.

[FirebaseStorageSwift](FirebaseStorageSwift) is an example that extends
FirebaseStorage with APIs that take advantage of Swift's Result type.
[FirebaseFirestoreSwift](Firestore/Swift) is a larger library that adds
Codable support for Firestore.

Add more such APIs to improve the Firebase Swift API.

More examples in the
[feature requests](https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aopen+is%3Aissue+label%3A%22Swift+API%22).

### SwiftUI

Firebase should be better integrated with SwiftUI apps. See SwiftUI related
[issues](https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aissue+is%3Aopen++label%3ASwiftUI).

### Swift Async/Await

Evaluate impact on Firebase APIs of the
[Swift Async/await proposal](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md).
For example, Objective C callback APIs that return a value do not get an
async/await API automatically generated and an explicit function may need to be
added. See these
[Firebase Storage examples](https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseStorageSwift/Sources/AsyncAwait.swift).

### Combine

Firebase has community support for Combine (Thanks!). See
[Combine Readme](FirebaseCombineSwift/README.md) for usage and project details.

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
Continue the work done in 2020 and 2021 that used better Swift style, SwiftUI,
Swift Package Manager, async/await APIs, and multi-platform support for
[Analytics](https://github.com/firebase/quickstart-ios/tree/master/analytics),
[ABTesting](https://github.com/firebase/quickstart-ios/tree/master/abtesting),
[Auth](https://github.com/firebase/quickstart-ios/tree/master/authentication),
[Database](https://github.com/firebase/quickstart-ios/tree/master/database),
[Functions](https://github.com/firebase/quickstart-ios/tree/master/functions),
[Performance](https://github.com/firebase/quickstart-ios/tree/master/performance),
and
[RemoteConfig](https://github.com/firebase/quickstart-ios/tree/master/config).

## Product Improvements

- [Issues marked with help-wanted tag](https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22+)
- [Pitches](https://github.com/firebase/firebase-ios-sdk/discussions/categories/pitches)
Propose and discuss ideas for Firebase improvements.
- [Feature requests](https://github.com/firebase/firebase-ios-sdk/issues?q=is%3Aissue+is%3Aopen+label%3A%22type%3A+feature+request%22)
- [All open issues](https://github.com/firebase/firebase-ios-sdk/issues)

Indicate your interest in contributing to a bug fix or feature request with a
comment. If you would like someone else to solve it, add a thumbs-up.

If you don't see the feature you're looking for, please add a
[Feature Request](https://github.com/firebase/firebase-ios-sdk/issues/new/choose).

## Improving the contributor experience

Please help others to be contributors by filing issues and adding PRs to ease
the learning curve to develop, test, and contribute to this repo.
