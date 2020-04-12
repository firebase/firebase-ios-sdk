# Firebase services require valid Firebase options
## Firebase Options
[Firebase options](https://firebase.google.com/docs/reference/ios/firebasecore/api/reference/Classes/FIROptions) are a set of parameters required by services in order to successfully communicate with Firebase server APIs and in order to associate client data with your Firebase project and Firebase application.

Firebase services rely on valid Firebase options being available from the Firebase core SDK [`FIRApp`](https://firebase.google.com/docs/reference/ios/firebasecore/api/reference/Classes/FIRApp), created during Firebase initialization.

Different Firebase services require different Firebase options to function properly, but all Firebase services require the following Firebase options:
* [**API key**](https://cloud.google.com/docs/authentication/api-keys) - Note: this is **not** an FCM server key, see below. \
  Example value: `AIzaSyDOCAbC123dEf456GhI789jKl012-MnO`
* [**Project ID**](https://firebase.google.com/docs/projects/learn-more#project-id) \
  Example value: `ios-myapp-123`
* **Application ID**, a.k.a. `GOOGLE_APP_ID`, `mobilesdk_app_id`, "AppId" - Note: this is **not** an Android package name! \
  Example value: `1:1234567890:ios:321abc456def7890`

## What do I need to know?
To improve security Firebase SDK updates [on January 14](https://firebase.google.com/support/release-notes/ios#version_6150_-_january_14_2020) and afterwards replaced the Firebase Instance ID service with a dependency on the [Firebase Installations API](https://console.cloud.google.com/apis/library/firebaseinstallations.googleapis.com).

Firebase Installations enforces the existence and validity of mandatory Firebase options API key, Project ID, and Application ID in order to associate client data with your Firebase project.

## Firebase Cloud Messaging (FCM) with Firebase Instance ID (IID)
If you are reading this message, most likely your application is initializing Firebase without the required set of Firebase options.

Your application may be using an incomplete or erroneous [`GoogleService-Info.plist`](https://firebase.google.com/docs/reference/android/com/google/firebase/FirebaseApp) configuration file; or your app is [programmatically initializing Firebase](https://firebase.google.com/docs/projects/multiprojects) without the full set of required Firebase options.

As a result, Firebase services like Firebase Cloud Messaging (FCM) will malfunction for end-users who installed your app after it was released with the updated Firebase SDKs. Additionally, repeated failing requests to Firebase may slow down the end-user experience of your app.

## What do I need to do?
To fix malfunctioning Firebase services for your applications, **please take the following steps as soon as possible:**
1. Update your application by initializing Firebase with a valid API key of your project, a valid Project ID, and a valid Application ID (a.k.a. GOOGLE_APP_ID, mobilesdk_app_id, or simply "App Id").
    * **Default initialization process using a Firebase config file**: [Download your `GoogleService-Info.plist` config file](https://support.google.com/firebase/answer/7015592) from the Firebase console, then replace the existing file in your app.
    * **Programmatic initialization using a `FIROptions` object**: [Download your `GoogleService-Info.plist` config file](https://support.google.com/firebase/answer/7015592) from the Firebase console to find your API key, Project ID, and Application ID, then update these values in the `FirebaseOptions` object in your app.
1. Release a new version of your app to the App Store.

## FCM Server keys
If your app is using an [FCM Server key](https://firebase.google.com/docs/cloud-messaging/auth-server#authorize-legacy-protocol-send-requests) rather than a Cloud API key, this could cause a security vulnerability in case you are using the same FCM Server key to send push notifications via FCM. \
In this case, we strongly recommend that you revisit how your server [authenticates send requests to FCM.](https://firebase.google.com/docs/cloud-messaging/auth-server)

Please note that FCM Server Keys (not the same as the Firebase / Cloud API key) must not be included in applications as they can be abused to send push-notifications in the name of your project.

You can [reach out to support](https://firebase.google.com/support/contact?utm_source=email&utm_medium=email&utm_campaign=firebase-installations-api-restrictions-problem) at any time if you have any questions.
