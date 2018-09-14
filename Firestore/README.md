## Usage

  * Set up a workspace via CocoaPods
    ```
    $ cd Firestore/Example
    $ pod update
    $ open Firestore.xcworkspace
    ```
  * Select the Firestore_Tests_iOS scheme
  * ⌘-u to build and run the unit tests

### Running Integration Tests

  * [Set up a `GoogleServices-Info.plist`](//github.com/firebase/firebase-ios-sdk#running-sample-apps)
    file in `Firestore/Example/App`.
  * In Xcode select the Firestore_IntegrationTests_iOS scheme
  * ⌘-u to build and run the integration tests

### Building Protos

Typically you should not need to worrying about regenerating the Objective-C
files from the .proto files. If you do, see instructions at
[Protos/README.md](Protos/README.md).
