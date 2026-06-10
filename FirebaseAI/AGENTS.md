# FirebaseAI Codebase Map

This file provides a consolidated overview of the `FirebaseAI` directory structure and its contents, intended to help AI agents navigate and understand the codebase efficiently.

---

## Sources/

This directory contains the main source code for the FirebaseAI library.

### Files in `Sources/`

- **`AILog.swift`**: Defines an internal `AILog` enum for logging within the Firebase AI SDK. It includes a `MessageCode` enum for various log messages and helper functions for logging at different levels (error, warning, notice, info, debug).
- **`Chat.swift`**: Defines the `Chat` class, which represents a back-and-forth chat with a `GenerativeModel`. It manages the chat history and provides methods for sending messages.
- **`Constants.swift`**: Defines a `Constants` enum containing constants for the Firebase AI SDK, such as the base error domain.
- **`Errors.swift`**: Defines various error-related structs and enums used for parsing and representing errors from the backend, such as `ErrorStatus` and `RPCStatus`.
- **`FirebaseAI.swift`**: The primary entry point for using the Firebase AI SDK. It provides factory methods for creating `GenerativeModel`, `ImagenModel`, and `LiveGenerativeModel` instances.
- **`FirebaseInfo.swift`**: Encapsulates Firebase-related information used by the SDK, such as project ID, API key, App Check, and Auth interop instances.
- **`GenAIURLSession.swift`**: Provides a `GenAIURLSession` enum with a default `URLSession` instance for the SDK to use.
- **`GenerateContentError.swift`**: Defines the public `GenerateContentError` enum, representing errors that can occur when generating content.
- **`GenerateContentRequest.swift`**: Defines the `GenerateContentRequest` struct, representing a request to generate content from the model.
- **`GenerateContentResponse.swift`**: Represents the model's response to a generate content request, including usage metadata, candidates, and prompt feedback.
- **`GenerationConfig.swift`**: Defines the `GenerationConfig` struct for configuring model parameters (e.g., temperature, topP).
- **`GenerativeAIRequest.swift`**: Defines the `GenerativeAIRequest` protocol for requests sent to the generative AI backend.
- **`GenerativeAIService.swift`**: Responsible for making requests to the generative AI backend, handling authentication, URL construction, and response parsing.
- **`GenerativeModel.swift`**: Defines the `GenerativeModel` class, representing a remote multimodal model. It provides methods for generating content and starting chats.
- **`GenerativeModelSession.swift`**: Provides a simplified interface for single-turn interactions, particularly useful for generating typed objects using the `@Generable` macro.
- **`History.swift`**: A thread-safe class for managing chat history, used by the `Chat` class.
- **`JSONValue.swift`**: Defines the `JSONValue` enum and `JSONObject` typealias for representing JSON values.
- **`ModalityTokenCount.swift`**: Represents token counting information for a single modality.
- **`ModelContent.swift`**: Represents the content of a message to or from the model (can contain multiple `Part`s).
- **`PartsRepresentable.swift`**: Protocol implemented by types that can be converted into an array of `Part`s.
- **`PartsRepresentable+Image.swift`**: Extends `UIImage`, `NSImage`, etc., to conform to `PartsRepresentable`.
- **`Safety.swift`**: Structs and enums related to safety settings and ratings (e.g., `HarmCategory`).
- **`TemplateChatSession.swift`**: Chat session that uses a prompt template.
- **`TemplateGenerateContentRequest.swift`**: Request for generating content from a template.
- **`TemplateGenerativeModel.swift`**: Model for generating content from a prompt template.
- **`TemplateImagenGenerationRequest.swift`**: Request for generating images from a template.
- **`TemplateImagenModel.swift`**: Model for generating images from a prompt template.
- **`TemplateInput.swift`**: Defines the `TemplateInput` enum for representing different types of input to a template.
- **`Tool.swift`**: Structs and enums related to tools and function calling (e.g., `FunctionDeclaration`).

---

## Sources/Protocols/

This directory contains Swift protocols used throughout the FirebaseAI library.

### Public Protocols

- **`ConvertibleFromGeneratedContent.swift`**: Defines `ConvertibleFromGeneratedContent` protocol for types that can be initialized from `GeneratedContent`.
- **`ToolRepresentable.swift`**: Protocol for types that can be represented as a tool in `FirebaseAILogic`.

### Internal Protocols

- **`CodableProtoEnum.swift`**: Provides helper protocols for encoding and decoding protobuf enums (`ProtoEnum`, `DecodableProtoEnum`, `EncodableProtoEnum`).
- **`ConvertibleToGeneratedContent.swift`**: Defines `ConvertibleToGeneratedContent` protocol for internal use.

---

## Sources/Types/

Data types used in the FirebaseAI library.

### Public Types

- **`Backend.swift`**: Used to configure the backend API (Vertex AI or Google AI).
- **`ImageConfig.swift`**: Defines the `ImageConfig` struct, used for configuring generated image properties like aspect ratio and size.
- **`Part.swift`**: Defines the `Part` protocol and conforming structs (Text, InlineData, FunctionCall, etc.).
- **`ResponseModality.swift`**: Represents types of data a model can produce (text, image, audio).
- **`Schema.swift`**: Allows definition of input and output data types for function calling.
- **`ThinkingConfig.swift`**: Controls the "thinking" behavior of compatible Gemini models.
- **`URLContextMetadata.swift`**: Metadata related to the `Tool.urlContext()` tool.
- **`URLMetadata.swift`**: Metadata for a single URL retrieved by the `Tool.urlContext()` tool.

#### Sources/Types/Public/Tools/

- **`GoogleMaps.swift`**: Tool that allows the model to ground responses in data from Google Maps.
- **`CodeExecution.swift`**: Tool that allows the model to execute code (currently an empty marker struct).

#### Sources/Types/Public/Imagen/

- **`ImagenAspectRatio.swift`**: Represents aspect ratios for generated images (e.g., `square1x1`).
- **`ImagenGenerationConfig.swift`**: Configuration options (negative prompt, aspect ratio, format, etc.).
- **`ImagenGenerationResponse.swift`**: Response containing generated images and potential filter reasons.
- **`ImagenImageFormat.swift`**: Image format options (PNG, JPEG).
- **`ImagenImagesBlockedError.swift`**: Error thrown when all generated images are blocked.
- **`ImagenInlineImage.swift`**: Represents an image generated as inline data.
- **`ImagenModel.swift`**: Main entry point for generating images.
- **`ImagenPersonFilterLevel.swift`**: Filter level for generating images with people.
- **`ImagenSafetyFilterLevel.swift`**: Filter level for sensitive content.
- **`ImagenSafetySettings.swift`**: Settings combining safety and person filter levels.

#### Sources/Types/Public/Live/

- **`AudioTranscriptionConfig.swift`**: Used to enable and configure audio transcriptions for Gemini Live.
- **`LiveAudioTranscription.swift`**: Represents text transcription of audio during live interaction.
- **`LiveGenerationConfig.swift`**: Configuration options for live content generation.
- **`LiveGenerativeModel.swift`**: Multimodal model supporting bidirectional streaming.
- **`LiveServerContent.swift`**: Incremental server update generated by the model.
- **`LiveServerGoingAwayNotice.swift`**: Notification from the server that it will disconnect soon.
- **`LiveServerMessage.swift`**: Represents an update from the server (content, tool call, etc.).
- **`LiveServerToolCall.swift`**: Request from server for client to execute function calls.
- **`LiveServerToolCallCancellation.swift`**: Notification to cancel a previous function call.
- **`LiveSession.swift`**: Represents a live WebSocket session with methods to send real-time data.
- **`LiveSessionErrors.swift`**: Public error structs related to live sessions.
- **`SpeechConfig.swift`**: Controls the voice of the model during conversation.

#### Sources/Types/Public/StructuredOutput/

- **`GeneratedContent.swift`**: Represents structured content generated by a model (wraps `FoundationModels.GeneratedContent`).
- **`GenerationSchema.swift`**: Wraps `FoundationModels.GenerationSchema` for structured output.
- **`GenerationID.swift`**: An identifier for a specific generation.

### Internal Types

- **`ProtoDuration.swift`**: Represents a signed, fixed-length span of time (mappings to `google.protobuf.duration`).
- **`InternalPart.swift`**: Defines internal representations for various part types (`InlineData`, `FileData`, etc.).
- **`DataType.swift`**: Enum for OpenAPI data types used in schemas.
- **`APIConfig.swift`**: Configures the generative AI backend API used by the SDK.
- **`AppCheck.swift`**: Internal helper extension for fetching App Check tokens.
- **`ProtoDate.swift`**: Represents a whole or partial calendar date (mappings to `google.type.Date`).

#### Sources/Types/Internal/Tools/

- **`URLContext.swift`**: Empty struct serving to enable the URL context tool.

#### Sources/Types/Internal/Imagen/

- **`ImageGenerationInstance.swift`**: Contains the prompt string.
- **`ImageGenerationOutputOptions.swift`**: Contains mimeType and compression quality.
- **`ImageGenerationParameters.swift`**: Holds all parameters for an image generation request.
- **`ImagenConstants.swift`**: Constants for the Imagen feature.
- **`ImagenGCSImage.swift`**: Represents an image stored in Google Cloud Storage.
- **`ImagenGenerationRequest.swift`**: Encapsulates the entire request sent to the Imagen API.
- **`ImagenImageRepresentable.swift`**: Protocol for types representable as an Imagen image.
- **`ImagenSafetyAttributes.swift`**: Prediction related to safety (currently unused).
- **`InternalImagenImage.swift`**: Internal representation of an Imagen image.
- **`RAIFilteredReason.swift`**: Reason why an image was filtered by Responsible AI.

#### Sources/Types/Internal/Requests/

- **`CountTokensRequest.swift`**: Request structure for the `countTokens` API endpoint.

#### Sources/Types/Internal/Live/

- **`AsyncWebSocket.swift`**: Async/await wrapper around `URLSessionWebSocketTask`.
- **`BidiGenerateContentClientContent.swift`**: Incremental update delivered from the client.
- **`BidiGenerateContentClientMessage.swift`**: Messages a client can send in a bidirectional stream.
- **`BidiGenerateContentRealtimeInput.swift`**: User input sent in real time (audio, video, etc.).
- **`BidiGenerateContentServerContent.swift`**: Incremental server update.
- **`BidiGenerateContentServerMessage.swift`**: Response message from server.
- **`BidiGenerateContentSetup.swift`**: First message sent by client to configure stream.
- **`BidiGenerateContentSetupComplete.swift`**: Sent by server to indicate setup is complete.
- **`BidiGenerateContentToolCall.swift`**: Request from server for function calls.
- **`BidiGenerateContentToolCallCancellation.swift`**: Notification to cancel a tool call.
- **`BidiGenerateContentToolResponse.swift`**: Client response to a tool call.
- **`BidiGenerateContentTranscription.swift`**: Transcribed text from audio input.
- **`BidiGenerationConfig.swift`**: Config for live content generation.
- **`BidiSpeechConfig.swift`**: Speech generation configuration.
- **`GoAway.swift`**: Notification from server that it will disconnect soon.
- **`LiveSessionService.swift`**: Actor managing connection and communication for a `LiveSession`.
- **`VoiceConfig.swift`**: Configuration for the speaker's voice.

#### Sources/Types/Internal/Errors/

- **`BackendError.swift`**: Captures detailed error information from the backend service.
- **`EmptyContentError.swift`**: Specific error for when a candidate has no content and no finish reason.

---

## Sources/Extensions/Internal/

Contains internal extensions to data models and other types.

- **`GenerationSchema+Gemini.swift`**: Extends `GenerationSchema` to transform the schema into a format compatible with the Gemini backend.
- **`JSONSerialization+prettyString.swift`**: Adds a helper method to `JSONSerialization` for pretty-printing JSON data.
- **`ConvertibleFromGeneratedContent+Firebase.swift`**: Extends `FoundationModels.ConvertibleFromGeneratedContent` to initialize from `FirebaseAI.GeneratedContent`.
