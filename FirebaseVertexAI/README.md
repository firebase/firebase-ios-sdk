# Vertex AI for Firebase SDK

- For developer documentation, please visit https://firebase.google.com/docs/vertex-ai.
- Try out the [sample app](Sample/README.md) to get started.

## Development

After following the Swift Package Manager
[setup instructions](https://github.com/firebase/firebase-ios-sdk#swift-package-manager-1),
choose the `FirebaseVertexAI` scheme to build the SDK.

### Unit Tests

> [!IMPORTANT]
> These unit tests require mock response files, which can be downloaded by
running `scripts/update_vertexai_responses.sh` from the root of this repository.

Choose the `FirebaseVertexAIUnit` scheme to build and run the unit tests.

#### Updating Mock Responses

To update the mock responses, create a PR in the
[`vertexai-sdk-test-data`](https://github.com/FirebaseExtended/vertexai-sdk-test-data)
repo. After it is merged, re-run the
[`update_vertexai_responses.sh`](https://github.com/firebase/firebase-ios-sdk/blob/main/scripts/update_vertexai_responses.sh)
script to download the updated files.
