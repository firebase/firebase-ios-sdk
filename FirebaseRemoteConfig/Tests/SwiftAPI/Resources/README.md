# Remote Config Console API

[`RemoteConfigConsole.swift`](https://github.com/firebase/firebase-ios-sdk/blob/nc-rc-test-api/FirebaseRemoteConfig/Tests/SwiftAPI/RemoteConfigConsole.swift) provides a simple API for interacting with an app's remote config on the Firebase console.

## Local Development Setup

You can start by generating the `FirebaseRemoteConfig` project:
```bash
pod gen FirebaseRemoteConfig.podspec --local-sources=./ --auto-open --platforms=ios
```

Next, create an accompanying Firebase project on the console and download the  `GoogleService-Info.plist`. Then, drag the `GoogleService-Info.plist` into the generated Remote Config Xcode project.

While the `RemoteConfigConsole` API basically just makes simple network calls, we will need to include an `access token` so our requests do the proper "handshake" with the Firebase console.

To generate the access token, we will need a **Firebase Service Account Private Key**

### Generating the Firebase Service Account Private Key
This private key is needed to create an access token with the valid parameters that authorizes our requests to programmtically make changes to remote config on the Firebase console.

Go to the Firebase console and navigate to your project's settings. Click on the **Service accounts** tab and and then generate the private key by clicking the blue button that says "Generate new private key"

A `.json` file will be downloaded. Go ahead and rename this file to `ServiceAccount.json` and move it to your `$HOME/.credentials/` directory. You may have to create the `.credentials/` directory.

### Create the Access Token
We use Google's [Auth Library for Swift](https://github.com/googleapis/google-auth-library-swift) to generate the access token. There are a few example use cases provided. We will use the [`TokenSource`](https://github.com/googleapis/google-auth-library-swift/blob/master/Sources/Examples/TokenSource/main.swift) example.

As you can see below when we set the `GOOGLE_APPLICATION_CREDENTIALS` env variable. This library will use the `ServiceAccount.json` file we generated earlier to create our access token.

#### Terminal Commands
```bash
$ git clone git@github.com:googleapis/google-auth-library-swift.git
$ cd google-auth-library-swift
$ make -f Makefile
$ export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.credentials/tokensource.json"
$ swift run TokenSource
> After a few seconds, the access token should print here 🥳
```
If your access token wasn't generated, scroll down to the **Troubleshooting** section.

Copy the access token and paste it into [`RemoteConfigConsole.swift`](https://github.com/firebase/firebase-ios-sdk/blob/nc-rc-test-api/FirebaseRemoteConfig/Tests/SwiftAPI/RemoteConfigConsole.swift). I have included a comment that you can replace with the token. It will be a long `String` but I would avoid trying to reformat it as to not clip any characters or add unneeded spacing.

🚀 Everything is ready to go! I recommend having the Firebase console up in one window so you can see the parameters change when the Xcode tests trigger changes.

## See it in action

Note: In the current [`APITests.swift`](https://github.com/firebase/firebase-ios-sdk/blob/nc-rc-test-api/FirebaseRemoteConfig/Tests/SwiftAPI/APITests.swift) tests, all of the tests that don't involve the `RemoteConfigConsole` expect there to be one remote config value already set up. If your app's remote config is empty and you want these tests to pass, manually add a parameter mapping `"Key1"` to `"Value1"`.

I have included a few tests in [`APITests.swift`](https://github.com/firebase/firebase-ios-sdk/blob/nc-rc-test-api/FirebaseRemoteConfig/Tests/SwiftAPI/APITests.swift) showcasing the  `RemoteConfigConsole` in action. Check out the following tests in [`APITests.swift`](https://github.com/firebase/firebase-ios-sdk/blob/nc-rc-test-api/FirebaseRemoteConfig/Tests/SwiftAPI/APITests.swift):
- [`testFetchConfigThenUpdateConsoleThenFetchAgain`](https://github.com/firebase/firebase-ios-sdk/blob/nc-rc-test-api/FirebaseRemoteConfig/Tests/SwiftAPI/APITests.swift#L192)
- [`testFetchConfigThenAddValueOnConsoleThenFetchAgain`](https://github.com/firebase/firebase-ios-sdk/blob/nc-rc-test-api/FirebaseRemoteConfig/Tests/SwiftAPI/APITests.swift#L229)
- [`testFetchConfigThenDeleteValueOnConsoleThenFetchAgain`](https://github.com/firebase/firebase-ios-sdk/blob/nc-rc-test-api/FirebaseRemoteConfig/Tests/SwiftAPI/APITests.swift#L264)

The **Firebase Service Account Private Key** only needs to be downloaded once. We can download it for the *internal remote config sample app* and upload it to GitHub secrets. Then we can decrypt and store it in the `$HOME/.credentials/` directory of the testing container when the pre-test scripts run.


## Troubleshooting
Initially, I ran into an issue where `$ swift run TokenSource` outputted:
```bash
error: terminated(72): xcrun --sdk macosx --find xctest output:
        xcrun: error: unable to find utility "xctest", not a developer tool or in PATH
```
If you run into this issue, try running: `$ xcode-select -p`. If you see:
```
/Library/Developer/CommandLineTools
```
Then the fix is simple! Run `$ sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` and verify it worked by running  `$ xcode-select -p` again. If you see:
```
/Applications/Xcode.app/Contents/Developer
```
Then you should be good to go! Try running `$ swift run TokenSource` again!
