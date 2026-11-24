# Firebase Installations integration test app

`FirebaseInstallationsTestApp.xcodeproj` runs the tests in `../Integration` in a host app that
depends on the repo's `Package.swift` through Swift Package Manager. The host app gives the tests
keychain access, which Swift Package Manager test bundles don't have.

The tests in `FIRInstallationsIntegrationTests.m` that talk to the Firebase Installations backend
need a `GoogleService-Info.plist` in this folder. It isn't checked in. Without it, those tests skip
themselves, unless `FIS_INTEGRATION_TESTS_REQUIRED=1` is set, which makes them fail. CI decrypts the
plist with:

```sh
scripts/repo.sh test --secrets ./scripts/secrets/Installations.json --platforms iOS Installations
```

To run the tests locally, open the project in Xcode and test the `FirebaseInstallationsTestApp-SPM`
scheme on an iOS or tvOS simulator, or run:

```sh
scripts/build.sh FirebaseInstallationsIntegration iOS
```

macOS isn't supported, because the integration tests need the keychain without a password prompt.
