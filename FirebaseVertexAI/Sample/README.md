# Vertex AI for Firebase Sample App

This sample demonstrates how to make calls to the Vertex AI Gemini API directly
from your app, rather than server-side, using the
[Vertex AI for Firebase SDK](https://firebase.google.com/docs/vertex-ai/get-started?platform=ios).

## Getting Started

### Clone and open the sample project

1. Clone this repo and checkout the `release-10.26` branch.
1. Change into the `FirebaseVertexAI/Sample` directory.
1. Open `VertexAISample.xcodeproj` using Xcode.

```bash
$ git clone https://github.com/firebase/firebase-ios-sdk.git
$ cd firebase-ios-sdk
$ git checkout release-10.26
$ cd FirebaseVertexAI/Sample
$ open VertexAISample.xcodeproj
```

### Connect the sample to your Firebase project

- To have a functional application, you will need to connect the Vertex AI for
  Firebase sample app to your Firebase project using the
  [Firebase Console](https://console.firebase.google.com).
- For an in-depth explanation, see
  [Add Firebase to your Apple project](https://firebase.google.com/docs/ios/setup).
  Below is a summary of the main steps:
  1. Visit the [Firebase Console](https://console.firebase.google.com).
  2. Add an iOS+ app to the project. Make sure the `Bundle Identifier` you set
     matches that of the one in the sample.
     - The default bundle ID is `com.google.firebase.VertexAISample`
  3. Download the `GoogleService-Info.plist` when prompted and save it to the
     `FirebaseVertexAI/Sample` directory, overwriting the placeholder file with
     the same name.
- Now you should be able to build and run the sample!

## Documentation

To learn more about the Vertex AI for Firebase SDK, check out the
[documentation](https://firebase.google.com/docs/vertex-ai).

## Support

- [GitHub Issue](https://github.com/firebase/firebase-ios-sdk/issues/new/choose)
  - File an issue in the `firebase-ios-sdk` repo, choosing the Vertex AI product.
- [Firebase Support](https://firebase.google.com/support/)
