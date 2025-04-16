# Vertex AI in Firebase Code Snippet Tests

These "tests" are for verifying that the code snippets provided in our
documentation continue to compile. They are intentionally skipped in CI but can
be manually run to verify expected behavior / outputs.

To run the tests, place a valid `GoogleService-Info.plist` file in the
[`FirebaseVertexAI/Tests/Unit/Resources`](https://github.com/firebase/firebase-ios-sdk/tree/main/FirebaseVertexAI/Tests/Unit/Resources)
folder. They may then be invoked individually or alongside the rest of the unit
tests in Xcode.
