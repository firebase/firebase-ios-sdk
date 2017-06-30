# Firebase Auth Development

This directory contains a set of samples and tests that integrate with
FirebaseAuth.

The Podfile specifies the dependencies and is used to construct an Xcode
workspace consisting of the samples, modifiable FirebaseAuth library, and its
dependencies.


### Running Sample Application

In order to run this application, you'll need to follow the following steps!

#### GoogleService-Info.plist files

You'll need valid `GoogleService-Info.plist` files for those samples. To get your own `GoogleService-Info.plist` files:
1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new Firebase project, if you don't already have one
3. For each sample app you want to test, create a new Firebase app with the sample app's bundle identifier (e.g. `com.google.FirebaseExperimental1.dev`)
4. Download the resulting `GoogleService-Info.plist` and place it in [Sample/GoogleService-Info.plist](Sample/GoogleService-Info.plist)

#### GoogleService-Info_multi.plist files

This feature is for advanced testing.
1. The developer would need to get a GoogleService-Info.plist from a different iOS client (which can be in a different Firebase project)
2. Save this plist file as GoogleService-Info_multi.plist in [Sample/GoogleService-Info_multi.plist](Sample/GoogleService-Info_multi.plist). This enables testing that FirebaseAuth continues to work after switching the Firebase App in the runtime.

#### Application.plist file

Please follow the instructions in [Sample/ApplicationTemplate.plist](Sample/ApplicationTemplate.plist) to generate the right Application.plist file

#### Getting your own Credential files

Please follow the instructions in [Sample/AuthCredentialsTemplate.h](Sample/AuthCredentialsTemplate.h) to generate the AuthCredentials.h file.


### Running SwiftSample Application

In order to run this application, you'll need to follow the following steps!

#### GoogleService-Info.plist files

You'll need valid `GoogleService-Info.plist` files for those samples. To get your own `GoogleService-Info.plist` files:
1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new Firebase project, if you don't already have one
3. For each sample app you want to test, create a new Firebase app with the sample app's bundle identifier (e.g. `com.google.FirebaseExperimental2.dev`)
4. Download the resulting `GoogleService-Info.plist` and place it in [SwiftSample/GoogleService-Info.plist](SwiftSample/GoogleService-Info.plist)

#### Info.plist file

Please follow the instructions in [SwiftSample/InfoTemplate.plist](SwiftSample/InfoTemplate.plist) to generate the right Info.plist file

#### Getting your own Credential files

Please follow the instructions in [SwiftSample/AuthCredentialsTemplate.swift](SwiftSample/AuthCredentialsTemplate.swift) to generate the AuthCredentials.swift file.

### Running API tests

In order to run the API tests, you'll need to follow the following steps!

#### Getting your own Credential files

Please follow the instructions in [ApiTests/AuthCredentialsTemplate.h](ApiTests/AuthCredentialsTemplate.h) to generate the AuthCredentials.h file.

## Usage

```
$ pod update
$ open Samples.xcworkspace
```
Then select a scheme and run.
