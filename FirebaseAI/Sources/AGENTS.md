# FirebaseAI Source Overview

This directory contains the source code for the FirebaseAI library.

## Directories

- **[`Protocols/`](Protocols/AGENTS.md)**: This directory contains Swift protocols used throughout the FirebaseAI library. These protocols define contracts for data models and services, ensuring a consistent and predictable structure.

- **[`Types/`](Types/AGENTS.md)**: This directory contains data types used in the FirebaseAI library. These types are organized into `Internal` and `Public` subdirectories.

## Files

- **`AILog.swift`**: Defines an internal `AILog` enum for logging within the Firebase AI SDK. It includes a `MessageCode` enum for various log messages, and helper functions for logging at different levels (error, warning, notice, info, debug). It also provides a way to enable verbose logging.
- **`Chat.swift`**: Defines the `Chat` class, which represents a back-and-forth chat with a `GenerativeModel`. It is instantiated via the `startChat(history:)` method on a `GenerativeModel` instance. It manages the chat history and provides `sendMessage` and `sendMessageStream` methods for sending messages to the model.
- **`Constants.swift`**: Defines a `Constants` enum containing constants for the Firebase AI SDK, such as the base error domain.
- **`Errors.swift`**: Defines various error-related structs and enums used for parsing and representing errors from the backend, such as `ErrorStatus`, `ErrorDetails`, and `RPCStatus`.
- **`FirebaseAI.swift`**: Defines the main `FirebaseAI` class, which is the primary entry point for using the Firebase AI SDK. It provides factory methods for creating `GenerativeModel`, `ImagenModel`, and `LiveGenerativeModel` instances.
- **`FirebaseInfo.swift`**: Defines the `FirebaseInfo` struct, which encapsulates Firebase-related information used by the SDK, such as project ID, API key, App Check, and Auth interop instances.
- **`GenAIURLSession.swift`**: Provides a `GenAIURLSession` enum with a `default` URLSession instance for the SDK to use. It includes a workaround for a simulator bug.
- **`GenerateContentError.swift`**: Defines the public `GenerateContentError` enum, which represents errors that can occur when generating content from a model.
- **`GenerateContentRequest.swift`**: Defines the `GenerateContentRequest` struct, which represents a request to generate content from the model.
- **`GenerateContentResponse.swift`**: Defines the `GenerateContentResponse` struct, which represents the model's response to a generate content request. It also defines nested structs like `UsageMetadata`, `Candidate`, `Citation`, `FinishReason`, `PromptFeedback`, and `GroundingMetadata`.
- **`GenerationConfig.swift`**: Defines the `GenerationConfig` struct for configuring model parameters for generative AI requests.
- **`GenerativeAIRequest.swift`**: Defines the `GenerativeAIRequest` protocol for requests sent to the generative AI backend. It also defines `RequestOptions`.
- **`GenerativeAIService.swift`**: Defines the `GenerativeAIService` struct, which is responsible for making requests to the generative AI backend. It handles things like authentication, URL construction, and response parsing.
- **`GenerativeModel.swift`**: Defines the `GenerativeModel` class, which represents a remote multimodal model. It provides methods for generating content, counting tokens, and starting a chat via `startChat(history:)`, which returns a `Chat` instance.
- **`GenerativeModelSession.swift`**: Defines the `GenerativeModelSession` class, which provides a simplified interface for single-turn interactions with a generative model. It's particularly useful for generating typed objects from a model's response using the `@Generable` macro, without the conversational turn-based structure of a `Chat`.
- **`History.swift`**: Defines the `History` class, a thread-safe class for managing the chat history, used by the `Chat` class.
- **`JSONValue.swift`**: Defines the `JSONValue` enum and `JSONObject` typealias for representing JSON values.
- **`ModalityTokenCount.swift`**: Defines the `ModalityTokenCount` and `ContentModality` structs for representing token counting information for a single modality.
- **`ModelContent.swift`**: Defines the `ModelContent` struct, which represents the content of a message to or from the model. It can contain multiple `Part`s.
- **`PartsRepresentable.swift`**: Defines the `PartsRepresentable` protocol, which is implemented by types that can be converted into an array of `Part`s.
- **`PartsRepresentable+Image.swift`**: Extends `UIImage`, `NSImage`, `CGImage`, and `CIImage` to conform to `PartsRepresentable`, allowing them to be used as input to the model.
- **`Safety.swift`**: Defines structs and enums related to safety settings and ratings, such as `SafetyRating`, `SafetySetting`, and `HarmCategory`.
- **`TemplateChatSession.swift`**: Defines the `TemplateChatSession` class for a chat session that uses a prompt template.
- **`TemplateGenerateContentRequest.swift`**: Defines the `TemplateGenerateContentRequest` struct for generating content from a template.
- **`TemplateGenerativeModel.swift`**: Defines the `TemplateGenerativeModel` class for generating content from a prompt template.
- **`TemplateImagenGenerationRequest.swift`**: Defines the `TemplateImagenGenerationRequest` struct for generating images from a template.
- **`TemplateImagenModel.swift`**: Defines the `TemplateImagenModel` class for generating images from a prompt template.
- **`TemplateInput.swift`**: Defines the `TemplateInput` enum for representing different types of input to a template.
- **`Tool.swift`**: Defines structs and enums related to tools and function calling, such as `FunctionDeclaration`, `Tool`, and `ToolConfig`.
