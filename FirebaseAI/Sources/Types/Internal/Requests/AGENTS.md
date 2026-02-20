# Gemini Code Assistant

This directory contains internal data types for API requests.
These types encapsulate the data that needs to be sent to the backend for various operations.
They are not part of the public API and can change at any time.

### Files:

- **`CountTokensRequest.swift`**: Defines the request structure for the `countTokens` API endpoint, which is used to calculate the number of tokens in a prompt. This includes the model name and the content to be tokenized. The request is encoded differently depending on the backend service (Vertex AI or Google AI) because the two backends have slightly different expectations for the `countTokens` endpoint. For example, the model resource name format differs between the two. The file also defines the `CountTokensResponse` struct.
