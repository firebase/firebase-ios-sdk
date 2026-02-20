# FirebaseAI Internal Request Types

This directory contains internal data types for API requests.
These types encapsulate the data that needs to be sent to the backend for various operations.
They are not part of the public API and can change at any time.

### Files

- **`CountTokensRequest.swift`**: Defines the request structure for the `countTokens` API endpoint, used to calculate the number of tokens in a prompt. It includes the model name and the content to be tokenized. The request encoding differs between Vertex AI and Google AI backends due to different API expectations (e.g., model resource name format). The file also defines the `CountTokensResponse` struct.
