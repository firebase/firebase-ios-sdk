# Firestore Swift Extensions

This directory contains source files for Firestore's Swift extensions SDK.

## Installation

The FirebaseFirestoreSwift module is currently only available for installation
through CocoaPods. To add FirebaseFirestoreSwift to your project, add the
following to your Podfile

```ruby
pod 'FirebaseFirestoreSwift'
```

You will need to import the FirebaseFirestoreSwift module in any source file
that depends on it, since it's not automatically bundled with the Firestore
module.

```swift
import Firebase
import FirebaseFirestoreSwift
```

The FirebaseFirestoreSwift module does not provide any additional utility to
Objective-C projects, and therefore is not recommended for non-Swift projects.

## Examples

See the
[Firestore quickstart sample](https://github.com/firebase/quickstart-ios/tree/master/firestore/FirestoreExample)
and the
[official Firebase documentation](https://firebase.google.com/docs/firestore/manage-data/add-data#custom_objects)
for usage examples.

## License

The Firestore Swift Extensions SDK is available under the Apache-2 license. See
the top-level LICENSE file for more details.
