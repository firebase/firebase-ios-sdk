# Firebase Options Usage By Product

Summarize which Firebase Options fields (and GoogleService-Info.plist attributes) are used by which Firebase products.

|                       | An    | ApC   | ApD   | Aut   | Cor   | Crs   | DB    | DL    | Fst   | Fn    | IAM   | Ins   | Msg   | MLM   | Prf   | RC    | Str   |
|   :---                | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **apiKey**            |       |  ✅   |  ✅  |  ✅   |       |       |       |  ✅   |       |       |  ✅   |  ✅   |       |     |  ✅  |   ✅    |      |
| **bundleID**          |       |       |       |       |   ✅  |       |       |       |       |       |       |       |       |       | ✅   |       |     |
| **clientID**          |       |       |       |  ✅   |       |       |       |       |       |       |       |       |       |       |       |       |     |
| **gcmSenderID**       |       |       |       |       |       |       |       |       |       |       |   ✅  |   ✅  |  ✅  |       |       |  ✅   |      |
| **projectID**         |       |   ✅  |       |       |       |       |   ✅ |       |  ✅  |  ✅   |        |  ✅   |       |  ✅  |   ✅  |  ✅   |       |
| **googleAppID**       |   ✅  |  ✅   |       |  ✅  |       |  ✅   |   ✅ |       |       |       |   ✅   |   ✅  | ✅   |       |  ✅   |   ✅ |   ✅ |
| **databaseURL**       |       |       |       |       |       |       |   ✅  |       |       |       |       |       |       |       |       |       |       |
| **deepLinkURLScheme** |       |       |       |       |       |       |       |    ✅ |       |       |       |       |       |       |       |       |       |
| **storageBucket**     |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |       |   ✅   |


## Rows (FirebaseOptions)
See [FIROptions.m](https://github.com/firebase/firebase-ios-sdk/blob/master/FirebaseCore/Sources/FIROptions.m) to see how the variables map
to GoogleService-Info.plist attributes.

* *apiKey*: An API key used for authenticating requests from your Apple app
* *bundleID*: The bundle ID for the application (Not used by the SDK)
* *clientID*: The OAuth2 client ID for Apple applications used to authenticate Google users
* *gcmSenderID*: The Project Number from the Google Developer's console used to configure Google Cloud Messaging
* *projectID*: The Project ID from the Firebase console
* *googleAppID*: The Google App ID that is used to uniquely identify an instance of an app
* *databaseURL*: The realtime database root URL
* *deepLinkURLScheme*: The URL scheme used to set up Durable Deep Link service
* *storageBucket*: The Google Cloud Storage bucket name

## Questions

Why isn't *deepLinkURLScheme* set from the GoogleService-Info.plist field `REVERSED_CLIENT_ID` like
other Firebase Options?

## Unused FirebaseOptions
* *androidClientID*
* *trackingID*

## Unread GoogleService-Info.plist fields
 * PLIST_VERSION
 * IS_ADS_ENABLED
 * IS_ANALYTICS_ENABLED
 * IS_APPINVITE_ENABLED
 * IS_GCM_ENABLED
 * IS_SIGNIN_ENABLED

## Columns (Firebase Products)
* An - Analytics
* ApC - App Check
* ApD - App Distribution
* Aut - Auth
* Cor - Core
* Crs - Crashlytics
* DB - Real-time Database
* DL - Dynamic Links
* Fst - Firestore
* Fn - Functions
* IAM - In App Messaging
* Ins - Installations
* Msg - Messaging
* MLM - MLModel Downloader
* Prf - Performance
* RC - Remote Config
* Str - Storage
