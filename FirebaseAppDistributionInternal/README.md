## Steps to test with Firebase App Distribution Internal

In your test app, add the following dependencies.

```
  pod 'FirebaseAppDistribution', :git => 'https://github.com/firebase/firebase-ios-sdk.git', :branch => 'fad/in-app-feedback'
  pod 'FirebaseAppDistributionInternal', :git => 'https://github.com/firebase/firebase-ios-sdk.git', :branch => 'fad/in-app-feedback'
```

For local testing, you can use a local path:

```
  pod 'FirebaseAppDistribution', :path => 'libraries/LocalPod/'
  pod 'FirebaseAppDistributionInternal', :path => 'libraries/LocalPod/'
```