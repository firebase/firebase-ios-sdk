## Steps to copy over changes in FirebaseAppDistributionInternal to master

For CI builds, this pod needs to be in master. To copy over changes, do the following:

1. `git checkout -b fad/appdistributioninternal`
1. `git checkout fad/in-app-feedback FirebaseAppDistributionInternal/`
1. `git checkout fad/in-app-feedback FirebaseAppDistributionInternal.podspec`

Then open a PR to merge these changes to master. This won't affect the public version of `FirebaseAppDistribution`.

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