# Sample Standalone watchOS App

This sample demonstrates how to use Firebase Cloud Messaging in a standalone watchOS app.

## Getting started

1. Turn on _Developer mode_ on your watch:
    - Settings > Privacy & Security > Developer Mode
    - You will have to restart your watch
1. Change the bundle identifier to a unique ID (e.g. `dev.<yourcompany>.WatchKitApp.dev.WatchKitApp`)
1. Enable automatic code signing for the Xcode project
1. [Add Firebase to your watchOS Project](https://firebase.google.com/docs/ios/setup)
    > **Warning**
    > Make sure to add the `GoogleServices-Info.plist` file to the `SampleStandaloneWatchApp Watch App` target
1. [Upload your APNs authentication key to Firebase](https://firebase.google.com/docs/cloud-messaging/ios/client#upload_your_apns_authentication_key)
1. Run the app
1. When the app first launches, you will need to accept the notification permission
1. In the Firebase console, go to [Messaging](https://console.firebase.google.com/project/_/messaging/onboarding), and click on _Create your first campaign_
1. Select _Firebase Notification messages_ and click on _Create_
1. Enter a message in the _Notification text_ field
1. Click on the blue  _Send test message_ button on the right
    > **Note**
    > It is easy to miss this button. You have to click on the blue **Send test message** button on the **RIGHT HAND** side of the screen.
1. In the Xcode debug console, find the _FCM registration token_, and add it in the _Test on device_ dialog
1. Tick the checkbox for the token, then click on the _Test_ button
1. The message should now appear on your development watch