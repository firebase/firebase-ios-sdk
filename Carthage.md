# Firebase Carthage

## Context

This page introduces and provides instructions for an **experimental** Firebase
[Carthage](https://github.com/Carthage/Carthage) distribution. Based on
feedback and usage, the Firebase team may decide to [make the Carthage
distribution official](https://github.com/firebase/firebase-ios-sdk/issues/1862).

Please [let us know](https://github.com/firebase/firebase-ios-sdk/issues) if you
have suggestions or questions.

## Carthage Installation

[Homebrew](http://brew.sh/) is one way to install Carthage.

```bash
$ brew update
$ brew install carthage
```

See the
[Carthage page](https://github.com/Carthage/Carthage#installing-carthage) for
more details and additional installation methods.

## Carthage Usage

- Create a Cartfile with a **subset** of the following components - choosing the
Firebase components that you want to include in your app. Note that
**FirebaseAnalyticsBinary** must always be included.

```
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseABTestingBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAdMobBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAnalyticsBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAppCheckBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAppDistributionBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseAuthBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseCrashlyticsBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseDatabaseBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseDynamicLinksBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseFirestoreBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseFunctionsBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseGoogleSignInBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseInAppMessagingBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseMLModelDownloaderBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseMessagingBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebasePerformanceBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseRemoteConfigBinary.json"
binary "https://dl.google.com/dl/firebase/ios/carthage/FirebaseStorageBinary.json"
```
- Run `carthage update`
- Use Finder to open `Carthage/Build`.
- Copy the contents into the top level of your Xcode project and make sure
    they're added to the right build target(s).
    - To disable AdId support, do not copy
   `GoogleAppMeasurementIdentitySupport.xcframework`.
    - If the app does not use any Firebase Swift specific APIs, you do not need
   to copy any xcframeworks whose name includes "Swift".
- Add `$(OTHER_LDFLAGS) -ObjC` flag to "Other Linker Flags" in "Build Settings".
- Make sure that the build target(s) includes your project's `GoogleService-Info.plist`
 ([how to download config file](https://support.google.com/firebase/answer/7015592))
- [Delete Firebase.framework from the Link Binary With Libraries Build Phase](https://github.com/firebase/firebase-ios-sdk/issues/911#issuecomment-372455235).
- If you're including a Firebase component that has resources, copy its bundles
    into the Xcode project and make sure they're added to the
    `Copy Bundle Resources` Build Phase.

- Please note that you shouldn't add any of the Firebase frameworks to the Carthage build phase
 (`copy-frameworks`). The frameworks contain static libraries that are linked at build time.

- Some additional libraries/frameworks may be needed depending on which Firebase frameworks you
 use, for example: libc++.tbd, sqlite3.tbd, StoreKit.framework, etc. For more information,
 [go here](https://github.com/firebase/firebase-ios-sdk/issues/9#issuecomment-387947163).

- If you see Swift symbol linkage errors, you may need to add a dummy `.swift` file to the project
  to resolve.

- For Crashlytics, do the following steps to automatically upload your app's symbols so your app's crashes are symbolicated:
    - Download
     [upload-symbols](https://github.com/firebase/firebase-ios-sdk/raw/main/Crashlytics/upload-symbols)
     and [run](https://github.com/firebase/firebase-ios-sdk/raw/main/Crashlytics/run).
     Note: please see the [discussion](https://github.com/firebase/firebase-ios-sdk/issues/4720#issuecomment-577213858)
     for details why it has to be done manually.
    - Put these in the directory where your `.xcodeproj` file lives, eg. `scripts/run` and `scripts/upload-symbols`
    - Make sure that the files are executable - `chmod +x scripts/run scripts/upload-symbols`
    - Open your project in Xcode, then select its project file in the left navigator.
    - From the **Select a project or target** dropdown, select your main build target.
    - Select the **Build Phases** tab, then click "+" add > **New Run Script Phase**.
    - Paste the following into your new Run Script, replacing "scripts" with whatever you named your folder: `"${PROJECT_DIR}/scripts/run"`
    - Add the following dependencies as **Input Files** to the Run Script:
       - `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}`
       - `${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}`

## Versioning

All Firebase components share the same version.
Mixing and matching components with different versions may cause linker errors.

## Static Frameworks

Note that the Firebase frameworks in the distribution include static libraries.
While it is fine to link these into apps, it will generally not work to depend
on them from wrapper dynamic frameworks.

## Acknowledgements

Thanks to the Firebase community for encouraging this implementation including
those who have made this the most updated
[firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk)
[issue](https://github.com/firebase/firebase-ios-sdk/issues/9).

Thanks also to those who have already done Firebase Carthage implementations,
such as https://github.com/soheilbm/Firebase.
