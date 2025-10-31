// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import Foundation

/// A type that represents a remote multimodal model (like Gemini), with the ability to generate
/// content based on various input types.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class GenerativeModel: Sendable {
  /// Model name prefix to identify Gemini models.
  static let geminiModelNamePrefix = "gemini-"

  /// Model name prefix to identify Gemma models.
  static let gemmaModelNamePrefix = "gemma-"

  /// The name of the model, for example "gemini-2.0-flash".
  let modelName: String

  /// The model resource name corresponding with `modelName` in the backend.
  let modelResourceName: String

  /// Configuration for the backend API used by this model.
  let apiConfig: APIConfig

  /// The backing service responsible for sending and receiving model requests to the backend.
  let generativeAIService: GenerativeAIService

  /// Configuration parameters used for the MultiModalModel.
  let generationConfig: GenerationConfig?

  /// The safety settings to be used for prompts.
  let safetySettings: [SafetySetting]?

  /// A list of tools the model may use to generate the next response.
  let tools: [Tool]?

  /// Tool configuration for any `Tool` specified in the request.
  let toolConfig: ToolConfig?

  /// Instructions that direct the model to behave a certain way.
  let systemInstruction: ModelContent?

  /// Configuration parameters for sending requests to the backend.
  let requestOptions: RequestOptions

  /// Initializes a new remote model with the given parameters.
  ///
  /// - Parameters:
  ///   - modelName: The name of the model.
  ///   - modelResourceName: The model resource name corresponding with `modelName` in the backend.
  ///     The form depends on the backend and will be one of:
  ///       - Vertex AI via Firebase AI SDK:
  ///       `"projects/{projectID}/locations/{locationID}/publishers/google/models/{modelName}"`
  ///       - Developer API via Firebase AI SDK: `"projects/{projectID}/models/{modelName}"`
  ///       - Developer API via Generative Language: `"models/{modelName}"`
  ///   - firebaseInfo: Firebase data used by the SDK, including project ID and API key.
  ///   - apiConfig: Configuration for the backend API used by this model.
  ///   - generationConfig: The content generation parameters your model should use.
  ///   - safetySettings: A value describing what types of harmful content your model should allow.
  ///   - tools: A list of ``Tool`` objects that the model may use to generate the next response.
  ///   - toolConfig: Tool configuration for any `Tool` specified in the request.
  ///   - systemInstruction: Instructions that direct the model to behave a certain way; currently
  ///     only text content is supported.
  ///   - requestOptions: Configuration parameters for sending requests to the backend.
  ///   - urlSession: The `URLSession` to use for requests; defaults to `URLSession.shared`.
  init(modelName: String,
       modelResourceName: String,
       firebaseInfo: FirebaseInfo,
       apiConfig: APIConfig,
       generationConfig: GenerationConfig? = nil,
       safetySettings: [SafetySetting]? = nil,
       tools: [Tool]?,
       toolConfig: ToolConfig? = nil,
       systemInstruction: ModelContent? = nil,
       requestOptions: RequestOptions,
       urlSession: URLSession = GenAIURLSession.default) {
    self.modelName = modelName
    self.modelResourceName = modelResourceName
    self.apiConfig = apiConfig
    generativeAIService = GenerativeAIService(
      firebaseInfo: firebaseInfo,
      urlSession: urlSession
    )
    self.generationConfig = generationConfig
    self.safetySettings = safetySettings
    self.tools = tools
    self.toolConfig = toolConfig
    self.systemInstruction = systemInstruction.map {
      // The `role` defaults to "user" but is ignored in system instructions. However, it is
      // erroneously counted towards the prompt and total token count in `countTokens` when using
      // the Developer API backend; set to `nil` to avoid token count discrepancies between
      // `countTokens` and `generateContent`.
      ModelContent(role: nil, parts: $0.parts)
    }
    self.requestOptions = requestOptions

    if AILog.additionalLoggingEnabled() {
      AILog.debug(code: .verboseLoggingEnabled, "Verbose logging enabled.")
    } else {
      AILog.info(code: .verboseLoggingDisabled, """
      [FirebaseVertexAI] To enable additional logging, add \
      `\(AILog.enableArgumentKey)` as a launch argument in Xcode.
      """)
    }
    AILog.debug(code: .generativeModelInitialized, "Model \(modelResourceName) initialized.")
  }

  /// Generates content from String and/or image inputs, given to the model as a prompt, that are
  /// representable as one or more ``Part``s.
  ///
  /// Since ``Part``s do not specify a role, this method is intended for generating content from
  /// [zero-shot](https://developers.google.com/machine-learning/glossary/generative#zero-shot-prompting)
  /// or "direct" prompts. For
  /// [few-shot](https://developers.google.com/machine-learning/glossary/generative#few-shot-prompting)
  /// prompts, see `generateContent(_ content: [ModelContent])`.
  ///
  /// - Parameters:
  ///   - parts: The input(s) given to the model as a prompt (see ``PartsRepresentable`` for
  ///   conforming types).
  /// - Returns: The content generated by the model.
  /// - Throws: A ``GenerateContentError`` if the request failed.
  public func generateContent(_ parts: any PartsRepresentable...)
    async throws -> GenerateContentResponse {
    return try await generateContent([ModelContent(parts: parts)])
  }

  /// Generates new content from input content given to the model as a prompt.
  ///
  /// - Parameter content: The input(s) given to the model as a prompt.
  /// - Returns: The generated content response from the model.
  /// - Throws: A ``GenerateContentError`` if the request failed.
  public func generateContent(_ content: [ModelContent]) async throws
    -> GenerateContentResponse {
    try content.throwIfError()
    let response: GenerateContentResponse
    let generateContentRequest = GenerateContentRequest(
      model: modelResourceName,
      contents: content,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      tools: tools,
      toolConfig: toolConfig,
      systemInstruction: systemInstruction,
      apiConfig: apiConfig,
      apiMethod: .generateContent,
      options: requestOptions
    )
    do {
      response = try await generativeAIService.loadRequest(request: generateContentRequest)
    } catch {
      throw GenerativeModel.generateContentError(from: error)
    }

    // Check the prompt feedback to see if the prompt was blocked.
    if response.promptFeedback?.blockReason != nil {
      throw GenerateContentError.promptBlocked(response: response)
    }

    // Check to see if an error should be thrown for stop reason.
    if let reason = response.candidates.first?.finishReason, reason != .stop {
      throw GenerateContentError.responseStoppedEarly(reason: reason, response: response)
    }

    // If all candidates are empty (contain no information that a developer could act on) then throw
    if response.candidates.allSatisfy({ $0.isEmpty }) {
      throw GenerateContentError.internalError(underlying: InvalidCandidateError.emptyContent(
        underlyingError: Candidate.EmptyContentError()
      ))
    }

    return response
  }

  /// Generates content from String and/or image inputs, given to the model as a prompt, that are
  /// representable as one or more ``Part``s.
  ///
  /// Since ``Part``s do not specify a role, this method is intended for generating content from
  /// [zero-shot](https://developers.google.com/machine-learning/glossary/generative#zero-shot-prompting)
  /// or "direct" prompts. For
  /// [few-shot](https://developers.google.com/machine-learning/glossary/generative#few-shot-prompting)
  /// prompts, see `generateContentStream(_ content: @autoclosure () throws -> [ModelContent])`.
  ///
  /// - Parameters:
  ///   - parts: The input(s) given to the model as a prompt (see ``PartsRepresentable`` for
  ///   conforming types).
  /// - Returns: A stream wrapping content generated by the model or a ``GenerateContentError``
  ///     error if an error occurred.
  @available(macOS 12.0, *)
  public func generateContentStream(_ parts: any PartsRepresentable...) throws
    -> AsyncThrowingStream<GenerateContentResponse, Error> {
    return try generateContentStream([ModelContent(parts: parts)])
  }

  /// Generates new content from input content given to the model as a prompt.
  ///
  /// - Parameter content: The input(s) given to the model as a prompt.
  /// - Returns: A stream wrapping content generated by the model or a ``GenerateContentError``
  ///     error if an error occurred.
  @available(macOS 12.0, *)
  public func generateContentStream(_ content: [ModelContent]) throws
    -> AsyncThrowingStream<GenerateContentResponse, Error> {
    try content.throwIfError()
    let generateContentRequest = GenerateContentRequest(
      model: modelResourceName,
      contents: content,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      tools: tools,
      toolConfig: toolConfig,
      systemInstruction: systemInstruction,
      apiConfig: apiConfig,
      apiMethod: .streamGenerateContent,
      options: requestOptions
    )

    return AsyncThrowingStream { continuation in
      let responseStream = generativeAIService.loadRequestStream(request: generateContentRequest)
      Task {
        do {
          var didYieldResponse = false
          for try await response in responseStream {
            // Check the prompt feedback to see if the prompt was blocked.
            if response.promptFeedback?.blockReason != nil {
              throw GenerateContentError.promptBlocked(response: response)
            }

            // If the stream ended early unexpectedly, throw an error.
            if let finishReason = response.candidates.first?.finishReason, finishReason != .stop {
              throw GenerateContentError.responseStoppedEarly(
                reason: finishReason,
                response: response
              )
            }

            // Skip returning the response if all candidates are empty (i.e., they contain no
            // information that a developer could act on).
            if response.candidates.allSatisfy({ $0.isEmpty }) {
              AILog.log(
                level: .debug,
                code: .generateContentResponseEmptyCandidates,
                "Skipped response with all empty candidates: \(response)"
              )
            } else {
              continuation.yield(response)
              didYieldResponse = true
            }
          }

          // Throw an error if all responses were skipped due to empty content.
          if didYieldResponse {
            continuation.finish()
          } else {
            continuation.finish(throwing: GenerativeModel.generateContentError(
              from: InvalidCandidateError.emptyContent(
                underlyingError: Candidate.EmptyContentError()
              )
            ))
          }
        } catch {
          continuation.finish(throwing: GenerativeModel.generateContentError(from: error))
          return
        }
      }
    }
  }

  /// Creates a new chat conversation using this model with the provided history.
  public func startChat(history: [ModelContent] = []) -> Chat {
    return Chat(model: self, history: history)
  }

  /// Runs the model's tokenizer on String and/or image inputs that are representable as one or more
  /// ``Part``s.
  ///
  /// Since ``Part``s do not specify a role, this method is intended for tokenizing
  /// [zero-shot](https://developers.google.com/machine-learning/glossary/generative#zero-shot-prompting)
  /// or "direct" prompts. For
  /// [few-shot](https://developers.google.com/machine-learning/glossary/generative#few-shot-prompting)
  /// input, see `countTokens(_ content: @autoclosure () throws -> [ModelContent])`.
  ///
  /// - Parameters:
  ///   - parts: The input(s) given to the model as a prompt (see ``PartsRepresentable`` for
  ///   conforming types).
  /// - Returns: The results of running the model's tokenizer on the input; contains
  /// ``CountTokensResponse/totalTokens``.
  public func countTokens(_ parts: any PartsRepresentable...) async throws -> CountTokensResponse {
    return try await countTokens([ModelContent(parts: parts)])
  }

  /// Runs the model's tokenizer on the input content and returns the token count.
  ///
  /// - Parameter content: The input given to the model as a prompt.
  /// - Returns: The results of running the model's tokenizer on the input; contains
  /// ``CountTokensResponse/totalTokens``.
  public func countTokens(_ content: [ModelContent]) async throws -> CountTokensResponse {
    let requestContent = switch apiConfig.service {
    case .vertexAI:
      content
    case .googleAI:
      // The `role` defaults to "user" but is ignored in `countTokens`. However, it is erroneously
      // erroneously counted towards the prompt and total token count when using the Developer API
      // backend; set to `nil` to avoid token count discrepancies between `countTokens` and
      // `generateContent` and the two backend APIs.
      content.map { ModelContent(role: nil, parts: $0.parts) }
    }

    // When using the Developer API via the Firebase backend, the model name of the
    // `GenerateContentRequest` nested in the `CountTokensRequest` must be of the form
    // "models/model-name". This field is unaltered by the Firebase backend before forwarding the
    // request to the Generative Language backend, which expects the form "models/model-name".
    let generateContentRequestModelResourceName = switch apiConfig.service {
    case .vertexAI, .googleAI(endpoint: .googleAIBypassProxy):
      modelResourceName
    case .googleAI(endpoint: .firebaseProxyProd),
         .googleAI(endpoint: .firebaseProxyStaging):
      "models/\(modelName)"
    }

    let generateContentRequest = GenerateContentRequest(
      model: generateContentRequestModelResourceName,
      contents: requestContent,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      tools: tools,
      toolConfig: toolConfig,
      systemInstruction: systemInstruction,
      apiConfig: apiConfig,
      apiMethod: .countTokens,
      options: requestOptions
    )
    let countTokensRequest = CountTokensRequest(
      modelResourceName: modelResourceName, generateContentRequest: generateContentRequest
    )

    return try await generativeAIService.loadRequest(request: countTokensRequest)
  }

  /// Returns a `GenerateContentError` (for public consumption) from an internal error.
  ///
  /// If `error` is already a `GenerateContentError` the error is returned unchanged.
  private static func generateContentError(from error: Error) -> GenerateContentError {
    if let error = error as? GenerateContentError {
      return error
    }
    return GenerateContentError.internalError(underlying: error)
  }
}
