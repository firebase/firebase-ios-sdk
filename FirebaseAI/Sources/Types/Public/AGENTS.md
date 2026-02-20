# Gemini Code Assistant

This directory contains public data types that are part of the FirebaseAI library's public API.
These types are safe for developers to use and are documented in the official Firebase documentation.

The types are organized into subdirectories based on the feature they are related to, for example:
- `Imagen`: Public types related to Imagen models.
- `Live`: Public types related to real-time features.
- `Tools`: Public types for function calling.

When adding a new public type, it should be placed in the appropriate subdirectory.
Any changes to these types must be done carefully to avoid breaking changes for users.

### Files:

- **`Backend.swift`**: Defines the `Backend` struct, which is used to configure the backend API for the Firebase AI SDK. It provides static methods `vertexAI(location:)` and `googleAI()` to create instances for the respective backends.
- **`Part.swift`**: Defines the `Part` protocol and several conforming structs (`TextPart`, `InlineDataPart`, `FileDataPart`, `FunctionCallPart`, `FunctionResponsePart`, `ExecutableCodePart`, `CodeExecutionResultPart`). A `Part` represents a discrete piece of data in a media format that can be interpreted by the model.
- **`ResponseModality.swift`**: Defines the `ResponseModality` struct, which represents the different types of data that a model can produce as output (e.g., `text`, `image`, `audio`).
- **`Schema.swift`**: Defines the `Schema` class, which allows the definition of input and output data types for function calling. It supports various data types like string, number, integer, boolean, array, and object.
- **`ThinkingConfig.swift`**: Defines the `ThinkingConfig` struct, for controlling the "thinking" behavior of compatible Gemini models. It includes parameters like `thinkingBudget` and `includeThoughts`.
- **`URLContextMetadata.swift`**: Defines the `URLContextMetadata` struct, which contains metadata related to the `Tool.urlContext()` tool.
- **`URLMetadata.swift`**: Defines the `URLMetadata` struct, which contains metadata for a single URL retrieved by the `Tool.urlContext()` tool, including the `retrievalStatus`.
