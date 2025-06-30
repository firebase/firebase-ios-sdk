# Firebase AI SDK

- For developer documentation, please visit https://firebase.google.com/docs/ai-logic.
- Try out the [sample app](https://github.com/firebase/quickstart-ios/tree/main/firebaseai) to get started.

## Development

After following the Swift Package Manager
[setup instructions](https://github.com/firebase/firebase-ios-sdk#swift-package-manager-1),
choose the `FirebaseAI` scheme to build the SDK.

### Unit Tests

> [!IMPORTANT]
> These unit tests require mock response files, which can be downloaded by
running `scripts/update_vertexai_responses.sh` from the root of this repository.

Choose the `FirebaseAIUnit` scheme to build and run the unit tests.

#### Updating Mock Responses

To update the mock responses, create a PR in the
[`vertexai-sdk-test-data`](https://github.com/FirebaseExtended/vertexai-sdk-test-data)
repo. After it is merged, re-run the
[`update_vertexai_responses.sh`](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/update_vertexai_responses.sh)
script to download the updated files.
