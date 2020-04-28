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

### Improving the debugger experience

You can install a set of type formatters to improve the presentation of
Firestore internals in LLDB and Xcode. Add the following to your `~/.lldbinit` file:

```
command script import ~/path/to/firebase-ios-sdk/scripts/lldb/firestore.py
```

(substitute the location of your checkout of the firebase-ios-sdk.)

### Running Integration Tests

Prefer running the integration tests against the Firestore Emulator. This is
much faster than running against production and does not require you to
configure a Firestore-enabled project.

  * In a new terminal, run `scripts/run_firestore_emulator.sh` and leave it running.
  * In Xcode select the `Firestore_IntegrationTests_iOS` scheme (or macOS or tvOS).
  * ⌘-u to build and run the integration tests.

### Running Integration Tests - against production

Occasionally it's useful to run integration tests against a production account.


  * [Set up a `GoogleServices-Info.plist`](//github.com/firebase/firebase-ios-sdk#running-sample-apps)
    file in `Firestore/Example/App`.
  * Ensure your Firestore database has open rules (the integration tests do not
    authenticate).
  * In Xcode select the Firestore_IntegrationTests_iOS scheme
  * ⌘-u to build and run the integration tests

If you want to switch back to running integration tests against the emulator:

  * Ensure that `GoogleServices-Info.plist` is in its default state (`git
    checkout Firestore/Example/App/GoogleServices-Info.plist`).

### Building Protos

Typically you should not need to worrying about regenerating the C++ files from
the .proto files. If you do, see instructions at
[Protos/README.md](Protos/README.md).
