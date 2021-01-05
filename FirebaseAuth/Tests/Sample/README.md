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
[Sample/GoogleService-Info.plist](Sample/GoogleService-Info.plist)

#### GoogleService-Info\_multi.plist files

1. Create a second sample app and download its `GoogleService_Info.plist` file.  This can be in the
same Firebase project as the one above, or a different one.  Use a different app bundle identifier
(e.g.  `com.google.FirebaseExperimental2.dev`).
2. Save this plist file as `GoogleService-Info_multi.plist` in
[Sample/GoogleService-Info\_multi.plist](Sample/GoogleService-Info_multi.plist).
This enables testing that FirebaseAuth continues to work after switching the Firebase App in the
runtime.

#### Getting your own Credential files

Please follow the instructions in
[Sample/AuthCredentialsTemplate.h](Sample/AuthCredentialsTemplate.h)
to generate the AuthCredentials.h file.

#### Application.plist file

Generate the `Sample/Application.plist` file from
[Sample/ApplicationTemplate.plist](Sample/ApplicationTemplate.plist) by replacing `$BUNDLE_ID` and
`$REVERSED_CLIENT_ID` with their values from `GoogleService-Info.plist` and
`$REVERSED_CLIENT_MULTI_ID` with its value from `GoogleService-Info_multi.plist`.

This could be done in bash via something like this from within the `Sample` directory:
```bash
$ BUNDLE_ID=`xmllint --xpath "/plist/dict/key[.='BUNDLE_ID']/following-sibling::string[1]/text()" GoogleService-Info.plist`
$ REVERSED_CLIENT_ID=`xmllint --xpath "/plist/dict/key[.='REVERSED_CLIENT_ID']/following-sibling::string[1]/text()" GoogleService-Info.plist`
$ REVERSED_CLIENT_MULTI_ID=`xmllint --xpath "/plist/dict/key[.='REVERSED_CLIENT_ID']/following-sibling::string[1]/text()" GoogleService-Info_multi.plist`
$ sed \
      -e 's/\$BUNDLE_ID/'$BUNDLE_ID'/g' \
      -e 's/\$REVERSED_CLIENT_ID/'$REVERSED_CLIENT_ID'/g' \
      -e 's/\$REVERSED_CLIENT_MULTI_ID/'$REVERSED_CLIENT_MULTI_ID'/g' \
      ApplicationTemplate.plist > Application.plist
```

#### Sample.entitlements file

In order to test the "Reset Password In App" feature you will need to create a dynamic link for your
Firebase project in the Dynamic Links section of the Firebase Console. Once the link is created,
please copy the contents of
[Sample/SampleTemplate.entitlements](Sample/SampleTemplate.entitlements)
into a file named `Sample/Sample.entitlements` and replace `$KAPP_LINKS_DOMAIN` with your own
relevant appLinks domain. Your appLinks domains are domains that your app will handle as universal
links, in this particular case you can obtain this domain from the aforementioned Dynamic Links
section of the Firebase Console.


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
[SwiftSample/GoogleService-Info.plist](SwiftSample/GoogleService-Info.plist)

#### Info.plist file

Please follow the instructions in
[SwiftSample/InfoTemplate.plist](SwiftSample/InfoTemplate.plist)
to generate the right Info.plist file

#### Getting your own Credential files

Please follow the instructions in
[SwiftSample/AuthCredentialsTemplate.swift](SwiftSample/AuthCredentialsTemplate.swift)
to generate the AuthCredentials.swift file.

### Running API tests

In order to run the API tests, you'll need to follow the following steps!

#### Getting your own Credential files

Please follow the instructions in
[ApiTests/AuthCredentialsTemplate.h](ApiTests/AuthCredentialsTemplate.h)
to generate the AuthCredentials.h file.

#### Console

In the Firebase conosle for your test project, you'll need to enable the
following auth providers:
* Email/Password
* Google
* Facebook
* Anonymous

You'll also need to create a user with email
`user+email_existing_user@example.com` and password of `password`.

## Usage

```
$ pod update
$ open Firebase.xcworkspace
```
Then select an Auth scheme and run.
