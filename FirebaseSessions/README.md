# Firebase Sessions SDK

## Prerequisites
Follow the [Main Firebase Readme](https://github.com/firebase/firebase-ios-sdk#development)

## Development
### Generating the Project and Test Project

 - Test-based Development:
    - **Option 1:** `generate_project.sh` uses [cocoapods-generate](https://github.com/square/cocoapods-generate) to create an Xcode Workspace that has the SDK installed for all the SDK's supported platforms. This is useful for test-based development.
    - **Option 2:** `open Package.swift` in the root of the firebase-ios-sdk repo. You can run tests using the `FirebaseSessionsUnit` Scheme
 - `generate_testapp.sh` generates and opens a test app with the Sessions SDK included. This is useful for developing the Sessions SDK against a real app.

### Debugging Options

#### Switching Dev Environments - Autopush/Staging/Prod
SDK is configured to send events to different environments. To enforce different environments for sending events, we use an environment variable to configure the specific environment. Since environment variables are enforced in the context of the App, use the TestApp to send events to different environments after using the following configuration steps.

- Enter "Edit scheme" - On the title bar menu "Product" > "Scheme" > "Edit Scheme"
- Ensure "Run" is selected on the left tab
- On the right hand side, choose the "Arguments" tab
- Under the "Environment Variables", add the following variable to configure the environment
   - For "AUTOPUSH" - "FirebaseSessionsRunEnvironment" -> "AUTOPUSH"/"autopush"
   - For "STAGING" - "FirebaseSessionsRunEnvironment" -> "STAGING"/"staging"
   - For "PROD" - "FirebaseSessionsRunEnvironment" -> "PROD"/"prod"

NOTE: Default is PROD. Not configuring any flags would mean the events are sent to PROD environment.

#### Debugging Events
You can access command line parameters by following: Press `CMD-Shift-,` => Run => Arguments.

 - `-FIRSessionsDebugEvents` will print Session Start events to the console for debugging purposes.

#### Overriding Settings
You can override the Settings values fetched from the server using the app's Info.plist. The full list of override plist keys can be found in `LocalOverrideSettings.swift`.

 - **FirebaseSessionsEnabled**: Bool representing whether to make any network calls
 - **FirebaseSessionsTimeout**: Float number of seconds representing the time that an app must be backgrounded before generating a new session
 - **FirebaseSessionsSampingRate**: Float between 0 and 1 representing how often events are sent. 0 is drop everything, 1 is send everything.

### Updating the Proto
#### Prerequesites
To update the Sessions Proto, Protobuf is required. To install run:

```
brew install protobuf
```

#### Procedure
 1. Follow the directions in `sessions.proto` for updating it
 1. Run the following to regenerate the nanopb source files: `./FirebaseSessions/ProtoSupport/generate_protos.sh`
 1. Update the SDK to use the new proto fields


### Logging
The Sessions SDK uses the following strategy when determining log level:
 - **Info** should be used rarely. Because the Sessions SDK is a dependency of other products, customers will not expect regular logs from the SDK. Therefore, info events are not recommended except under circumstances where the code path is blocked by another debug parameter (eg. `-FIRSessionsDebugEvents` will log under info because we don't want to require it be paired with `-FIRDebugEnabled`)
 - **Debug** Is recommended to be used generously in the Sessions SDK for the purposes of debugging customer issues.
 - **Warning** Is used when the Sessions SDK runs into a recoverable issue that still results in events being sent. For example, a problem converting between values that results in an incorrect value being reported.
 - **Error** Is used when the Sessions SDK runs into an unrecoverable issue that prevents functionality from working. If we would want customers to reach out to us when a issue happens, then error logs should be used to convey the issue.
