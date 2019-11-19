## Usage

  * Install [prerequisite software](//github.com/firebase/firebase-ios-sdk#development)
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

### Running Integration Tests - using the Firestore Emulator

Note: this does not give full coverage, but is much faster than above.
b/hotlists/1578399 tracks outstanding issues.

  * Ensure that `GoogleServices-Info.plist` is back in its default state (`git
    checkout Firestore/Example/App/GoogleServices-Info.plist`).
  * [Install the Firebase CLI](https://firebase.google.com/docs/cli/).
    Essentially:
    ```
    npm install -g firebase-tools
    ```
  * [Install the Firestore
    emulator](https://firebase.google.com/docs/firestore/security/test-rules-emulator#install_the_emulator).
    Essentially:
    ```
    firebase setup:emulators:firestore
    ```
  * Run the emulator
    ```
    firebase serve --only firestore
    ```
  * In Xcode select the Firestore_IntegrationTests_iOS scheme
  * ⌘-u to build and run the integration tests

### Building Protos

Typically you should not need to worrying about regenerating the C++ files from
the .proto files. If you do, see instructions at
[Protos/README.md](Protos/README.md).
