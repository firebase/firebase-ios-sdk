# FirebaseAI Internal Error Types

This directory contains internal error types used within the FirebaseAI library.
These errors are not part of the public API and are used to handle specific error conditions within the SDK.

### Files

- **`BackendError.swift`**: Defines an error structure for capturing detailed error information from the backend service. It includes the HTTP response code, a message, an RPC status, and additional details. It conforms to `CustomNSError` to integrate with Cocoa error handling and provide richer error information.

- **`EmptyContentError.swift`**: Defines a specific error for when a `Candidate` is returned with no content and no finish reason. This is a nested struct within an extension of `Candidate`.
