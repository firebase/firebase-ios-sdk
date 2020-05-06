### Messaging App Setup

To run this app, you'll need the following steps.

#### GoogleService-Info.plist file

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Create a Firebase project if you don't have one already.
3. Create a new iOS App if you don't have one already.
4. Go to Project Overview -> General -> Your apps, select your iOS app and download the GoogleSerive-Info.plist file.


#### Push notification provisioning profile

If you need to test push notifications sent from FCM console or Sender API, you will need to run this test app on real device. In order to do so, you will need a provisioning profile enabled with push notifications.

Following the [steps](https://firebase.google.com/docs/cloud-messaging/ios/certs) here to setup the properly APNs configuration to work with Firebase Messaging.

