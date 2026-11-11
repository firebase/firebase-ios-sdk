// Copyright 2026 Google LLC
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

#if compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
  #if canImport(FoundationNetworking)
    import Foundation
    package import FoundationNetworking
  #else
    package import Foundation
  #endif
  #if FoundationModelsFake
    public import FoundationModelsFake
  #else
    public import FoundationModels
  #endif
  package import GeminiAPIClient

  /// **[Public Preview]** A Gemini language model adapter for the Foundation Models framework.
  ///
  /// > Warning: This API is a public preview and may be subject to change.
  ///
  /// To create an instance of ``GeminiLanguageModel``, use
  /// ``FirebaseAI/geminiLanguageModel(name:)`` on a ``FirebaseAI`` instance:
  /// ```swift
  /// let ai = FirebaseAI.firebaseAI()
  /// let model = ai.geminiLanguageModel(name: "gemini-model-name")
  /// let session = LanguageModelSession(model: model)
  /// ```
  ///
  /// This model conforms to Apple's
  /// [`LanguageModel`](https://developer.apple.com/documentation/foundationmodels/languagemodel)
  /// protocol and can be used with the Foundation Models framework when [initializing](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init%28model:tools:instructions:%29)
  /// a [`LanguageModelSession`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession),
  /// or by [setting the model](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofile/model%28_%29)
  /// on a [`DynamicProfile`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofile).
  ///
  /// For more details on using Gemini to generate content with the Foundation Models framework,
  /// see the getting started
  /// [guide](https://firebase.google.com/docs/ai-logic/apple-foundation-models-framework/get-started).
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GeminiLanguageModel: Sendable {
    /// The configuration for the executor responsible for translating Foundation Models requests to
    /// Gemini API calls.
    public let executorConfiguration: Executor.Configuration

    /// Initializes a new Gemini language model.
    ///
    /// - Parameters:
    ///   - modelResource: The Gemini model resource configuration.
    ///   - endpointConfiguration: The network endpoint configuration.
    ///   - headerProvider: An optional async provider for dynamic headers (such as auth tokens).
    ///   - configuration: The `URLSessionConfiguration` to use. Defaults to `.ephemeral`.
    package init(
      modelResource: ModelResource,
      endpointConfiguration: EndpointConfiguration,
      headerProvider: (@Sendable () async throws -> [String: String])? = nil,
      configuration: URLSessionConfiguration = .ephemeral
    ) {
      executorConfiguration = Executor.Configuration(
        modelResource: modelResource,
        endpointConfiguration: endpointConfiguration,
        headerProvider: headerProvider.map { HeaderProvider($0) },
        sessionConfiguration: configuration
      )
    }
  }

  // MARK: - LanguageModel Conformance

  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  extension GeminiLanguageModel: LanguageModel {
    /// The capabilities supported by this language model.
    ///
    /// ### Image input
    ///
    /// With the `vision` capability, prompts can include image attachments created from a
    /// `CGImage`, a `CIImage`, a `CVPixelBuffer`, or a file URL, such as `Attachment(cgImage)` or
    /// `Attachment(imageURL: fileURL)`. Images are sent inline with the request:
    ///
    /// - PNG, JPEG, WebP, HEIC, and HEIF files that don't need rotating are sent unchanged, unless
    ///   the file contains several images and its primary image isn't the first one.
    /// - All other images are rotated to their display orientation and re-encoded as JPEG. For
    ///   files that contain several images, the first image is used, matching
    ///   `Transcript.ImageAttachment`.
    ///
    /// Current limitations:
    ///
    /// - Image attachments are only supported in prompts, not in instructions or tool output.
    /// - Images from remote URLs (any URL that isn't a file URL) aren't supported.
    /// - Attachment labels aren't sent to the model, so tools that take an `ImageReference`, such
    ///   as Vision's `BarcodeReaderTool` and `OCRTool`, only work if the prompt text mentions the
    ///   label.
    /// - Inline data counts toward the backend's request size limit (about 20 MB), and earlier
    ///   images in the session are re-sent with every request.
    /// - Image files are read again for every request in the session, so a file must remain
    ///   available for as long as the session that references it is used.
    ///
    /// ### Tool calling
    ///
    /// With the `toolCalling` capability, the model can call the tools that you provide to the
    /// session. To limit cost when the model keeps calling tools, the model can make at most 10
    /// tool-calling turns in response to each prompt. A tool-calling turn is one response that
    /// calls one or more tools.
    ///
    /// - After 10 tool-calling turns, the next request tells Gemini not to call tools, so that
    ///   the model gives a final response.
    /// - If Gemini calls a tool anyway, the session throws
    ///   ``GeminiLanguageModel/Error/invalidResponse(_:)``.
    ///
    /// The limit also applies when the tool calling mode is `required`. With `required`, the model
    /// otherwise keeps calling tools until a tool throws an error or the mode changes. To stop
    /// sooner, change the mode with the [`toolCallingMode(_:)`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/dynamicprofile/toolcallingmode%28_%29)
    /// modifier of a `LanguageModelSession.DynamicProfile`, for example from `required` to
    /// `allowed` after the first tool call, as shown in [`GenerationOptions.ToolCallingMode`](https://developer.apple.com/documentation/foundationmodels/generationoptions/toolcallingmode-swift.struct).
    ///
    /// If Gemini calls a tool when the tool calling mode is `disallowed`, or calls a tool that
    /// isn't enabled for the request, the session throws
    /// ``GeminiLanguageModel/Error/invalidResponse(_:)`` and the tool doesn't run. Gemini doesn't
    /// always follow `disallowed` after several tool calls in response to a prompt, so prefer
    /// `allowed` when you change the mode after a tool call.
    ///
    /// By default, when the session throws an error, it reverts its transcript to how it was before
    /// the prompt, even if tools have already run. To keep the tool calls and their output, set the
    /// session's [`transcriptErrorHandlingPolicy`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/transcripterrorhandlingpolicy)
    /// to `preserveTranscript`.
    ///
    /// The limit is counted from the transcript that the session sends to the model, after any
    /// `historyTransform(_:)` of a `LanguageModelSession.DynamicProfile`. A transform that removes
    /// earlier tool calls can stop the limit from being reached, and a transform that removes
    /// prompts can make the limit apply across prompts.
    public var capabilities: LanguageModelCapabilities {
      LanguageModelCapabilities([
        .guidedGeneration,
        .reasoning,
        .toolCalling,
        .vision,
      ])
    }
  }
#endif  // compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
