# Remote Config Swift Tests

Currently the Remote Config tests run in two configurations:
1. Fake Console - mocks the console to run tests with a dummy GoogleService-Info.plist.
2. Remote Config Console API - relies on generating an access token to use a real Firebase project.

## Remote Config Console API

[`RemoteConfigConsole.swift`](https://github.com/firebase/firebase-ios-sdk/blob/main/FirebaseRemoteConfigSwift/Tests/SwiftAPI/RemoteConfigConsole.swift)
provides a simple API for interacting with an app's Remote Config on the
Firebase console.

### Local Development Setup
1. Create a Firebase project on the Firebase Console and download
the  `GoogleService-Info.plist`.
2. Navigate to your project's settings. Click on the **Service accounts** tab and
then download a private key by clicking the blue button that says "Generate new private key".
Rename it `ServiceAccount.json`.
3. Within the `firebase-ios-sdk`, run:
```bash
./scripts/generate_access_token.sh local_dev PATH/TO/ServiceAccount.json FirebaseRemoteConfigSwift/Tests/AccessToken.json
```
4. Generate the `FirebaseRemoteConfig` project:
```bash
pod gen FirebaseRemoteConfig.podspec --local-sources=./ --auto-open --platforms=ios
```
5. Copy the `GoogleService-Info.plist` you downloaded earlier into the generated
Xcode project.

🚀 Everything is ready to go! Run the tests in the `swift-api-tests` target.


### How it works

While the `RemoteConfigConsole` API basically just makes simple network calls,
we need to include an `access token` so our requests do the proper "handshake" with the Firebase console.

#### Firebase Service Account Private Key
This private key is needed to create an access token with the valid parameters
that authorizes our requests to programmatically make changes to remote config on the Firebase console.

The private key can be located on the Firebase console and navigate to your project's settings. To download,
click on the **Service accounts** tab and then generate the private key by clicking
the blue button that says "Generate new private key".

#### Create the Access Token
We use Google's [Auth Library for Swift](https://github.com/googleapis/google-auth-library-swift)
to generate the access token. There are a few example use cases provided. We use the
[`TokenSource`](https://github.com/googleapis/google-auth-library-swift/blob/master/Sources/Examples/TokenSource/main.swift)
example.

For the access token to be generated, the `GOOGLE_APPLICATION_CREDENTIALS` env var should be set to point to where the
Firebase project's service account key is stored. This is set in the
[`generate_access_token.sh`](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/generate_access_token.sh)
script.

#### Remote Config API Tests
There is a [section](https://github.com/firebase/firebase-ios-sdk/blob/main/FirebaseRemoteConfigSwift/Tests/SwiftAPI/APITests.swift#L210)
of tests in [`APITests.swift`](https://github.com/firebase/firebase-ios-sdk/blob/main/FirebaseRemoteConfigSwift/Tests/SwiftAPI/APITests.swift)
showcasing the  `RemoteConfigConsole` in action.
