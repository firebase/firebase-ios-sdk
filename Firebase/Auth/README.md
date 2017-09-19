# Firebase Auth for iOS

Firebase Auth enables apps to easily support multiple authentication options
for their end users.

Please visit [our developer site](https://firebase.google.com/docs/auth/) for
integration instructions, documentation, support information, and terms of
service.

# Firebase Auth Development

Example/Auth contains a set of samples and tests that integrate with
FirebaseAuth.

The Podfile specifies the dependencies and is used to construct an Xcode
workspace consisting of the samples, modifiable FirebaseAuth library, and its
dependencies.


### Running Sample Application

In order to run this application, you'll need to follow the following steps!

#### GoogleService-Info.plist files

You'll need valid `GoogleService-Info.plist` files for those samples. To get your own
`GoogleService-Info.plist` files:
1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new Firebase project, if you don't already have one
3. For each sample app you want to test, create a new Firebase app with the sample app's bundle
identifier (e.g. `com.google.FirebaseExperimental1.dev`)
4. Download the resulting `GoogleService-Info.plist` and place it in
[Example/Auth/Sample/GoogleService-Info.plist](../../Example/Auth/Sample/GoogleService-Info.plist)

#### GoogleService-Info_multi.plist files

This feature is for advanced testing.
1. The developer would need to get a GoogleService-Info.plist from a different iOS client (which
can be in a different Firebase project)
2. Save this plist file as GoogleService-Info_multi.plist in
[Sample/GoogleService-Info_multi.plist](Sample/GoogleService-Info_multi.plist).
This enables testing that FirebaseAuth continues to work after switching the Firebase App in the
runtime.

#### Application.plist file

Please follow the instructions in
[Example/Auth/Sample/ApplicationTemplate.plist](../../Example/Auth/Sample/ApplicationTemplate.plist)
to generate the right Application.plist file.

### Sample.entitlements file

In order to test the "Reset Password In App" feature you will need to create a dynamic link for your
Firebase project in the Dynamic Links section of the Firebase Console. Once the link is created,
please copy the contents of
[Example/Auth/Sample/SampleTemplate.entitlements](../../Example/Auth/Sample/SampleTemplate.entitlements)
into a file named `Sample/Sample.entitlements` and replace `$KAPP_LINKS_DOMAIN` with your own
relevant appLinks domain. Your appLinks domains are domains that your app will handle as universal
links, in this particular case you can obtain this domain from the aforementioned Dynamic Links
section of the Firebase Console.

#### Getting your own Credential files

Please follow the instructions in
[Example/Auth/Sample/AuthCredentialsTemplate.h](../../Example/Auth/Sample/AuthCredentialsTemplate.h)
to generate the AuthCredentials.h file.


### Running SwiftSample Application

In order to run this application, you'll need to follow the following steps!

#### GoogleService-Info.plist files

You'll need valid `GoogleService-Info.plist` files for those samples. To get your own
`GoogleService-Info.plist` files:
1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a new Firebase project, if you don't already have one
3. For each sample app you want to test, create a new Firebase app with the sample app's bundle
identifier (e.g. `com.google.FirebaseExperimental2.dev`)
4. Download the resulting `GoogleService-Info.plist` and place it in
[Example/Auth/SwiftSample/GoogleService-Info.plist](../../Example/Auth/SwiftSample/GoogleService-Info.plist)

#### Info.plist file

Please follow the instructions in
[Example/Auth/SwiftSample/InfoTemplate.plist](../../Example/Auth/SwiftSample/InfoTemplate.plist)
to generate the right Info.plist file

#### Getting your own Credential files

Please follow the instructions in
[Example/Auth/SwiftSample/AuthCredentialsTemplate.swift](../../Example/Auth/SwiftSample/AuthCredentialsTemplate.swift)
to generate the AuthCredentials.swift file.

### Running API tests

In order to run the API tests, you'll need to follow the following steps!

#### Getting your own Credential files

Please follow the instructions in
[Example/Auth/ApiTests/AuthCredentialsTemplate.h](../../Example/Auth/ApiTests/AuthCredentialsTemplate.h)
to generate the AuthCredentials.h file.

## Usage

```
$ pod update
$ open Firebase.xcworkspace
```
Then select an Auth scheme and run.
