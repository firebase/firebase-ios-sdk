## Usage

### Xcode

  * Install [prerequisite software](//github.com/firebase/firebase-ios-sdk#development)
  * Set up a workspace via CocoaPods (this opens Xcode):
    ```
    $ cd Firestore/Example
    $ pod update
    $ open Firestore.xcworkspace
    ```
  * Select the Firestore_Tests_iOS scheme
  * ⌘-u to build and run the unit tests

### Command-line builds

You can also build from the command-line, though this requires a slightly
different setup:

```
PLATFORM=iOS pod update --project-directory=Firestore/Example
scripts/build.sh Firestore iOS
```

Note:
  * `PLATFORM` here is specifying an environment variable that's active for the
    `pod update` invocation.
  * You can also use `macOS` or `tvOS` in place of `iOS` above.
  * This will modify the Xcode project files; you'll need to revert these
    changes to create a PR.

The [issue](https://github.com/CocoaPods/CocoaPods/issues/8729) that requires
this workaround is that Firestore's `Podfile` contains multiple platforms, and
ever since Xcode 10.2, CocoaPods generates Xcode projects that are break by
default when built by the `xcodebuild` command-line tool. There's a workaround
possible that involves disabling Xcode's default mechanism of finding implicit
dependencies, but this is something we'd have to disable Firebase-wide and
there hasn't been an appetite to do this.

### Swift package manager

Firestore also supports building with Swift Package Manager. To build this way
use:

```
scripts/build.sh Firestore iOS spm
```

This is rarely necessary for primary development and is done automatically by CI.

### Improving the debugger experience

You can install a set of type formatters to improve the presentation of
Firestore internals in LLDB and Xcode. Add the following to your `~/.lldbinit` file:

```
command script import ~/path/to/firebase-ios-sdk/scripts/lldb/firestore.py
```

(substitute the location of your checkout of the firebase-ios-sdk.)

## Testing

### Running Integration Tests

Prefer running the integration tests against the Firestore Emulator. This is
much faster than running against production and does not require you to
configure a Firestore-enabled project.

  * In a new terminal, run `scripts/run_firestore_emulator.sh` and leave it running.
  * In Xcode select the `Firestore_IntegrationTests_iOS` scheme (or macOS or tvOS).
  * ⌘-u to build and run the integration tests.

The command-line build script runs integration tests by default and will start
and stop an emulator for you.

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

### Testing composite index query against production
#### Setting Up the Environment:
1. [Set up a `GoogleServices-Info.plist`](//github.com/firebase/firebase-ios-sdk#running-sample-apps)
   file in `Firestore/Example/App`.
2. If not already logged in, authenticate with your Google Cloud Platform (GCP) account using
   `gcloud auth application-default login`. You can check your logged-in accounts by running
   `gcloud auth list`.
3. Navigate to the `Firestore` directory, create composite indexes by running:
    ```
    terraform init
    terraform apply -var="project_id=<your-project-id>" -auto-approve
    ```
4. Run integration tests as guided in "Running Integration Tests - against production".

Note: If the index creation encounters issues, such as concurrent operations, consider running the
index creation process again. Error messages indicating that indexes have already been created can
be safely disregarded.

#### Adding new composite index query tests
1. To create a new composite index for local development, click on the provided link in the test
   error message, which will direct you to the Firebase Console.
2. Add the newly created composite index to the `firestore_index_config.tf` file. The "__name__"
   field is not required to be explicitly added to the file, as the index creation will auto complete
   it on behalf.

## Other tasks

### Building Protos

Typically you should not need to worrying about regenerating the C++ files from
the .proto files. If you do, see instructions at
[Protos/README.md](Protos/README.md).
