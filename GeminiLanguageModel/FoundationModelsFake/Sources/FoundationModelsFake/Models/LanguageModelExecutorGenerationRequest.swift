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

#if compiler(>=6.4)
  #if canImport(FoundationEssentials)
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  /// A request passed to a language model executor to perform generation.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`LanguageModelExecutorGenerationRequest`](https://developer.apple.com/documentation/foundationmodels/languagemodelexecutorgenerationrequest).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct LanguageModelExecutorGenerationRequest: Sendable {
    /// The unique identifier of the generation request.
    public var id: UUID

    /// The transcript representing the conversation history for this request.
    public var transcript: Transcript

    /// The definitions of tools enabled for this generation request.
    public var enabledToolDefinitions: [Transcript.ToolDefinition]

    /// The schema constraining the response structure, or `nil` if unguided.
    public var schema: GenerationSchema?

    /// Options controlling generation parameters like temperature and sampling.
    public var generationOptions: GenerationOptions

    /// Options specifying context management limits.
    public var contextOptions: ContextOptions

    /// Arbitrary metadata associated with this request.
    public var metadata: [String: GeneratedContent]
  }

  extension LanguageModelExecutorGenerationRequest {
    /// Creates a generation request.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the request.
    ///   - transcript: The transcript representing the conversation history.
    ///   - enabledTools: The tool definitions available during generation.
    ///   - schema: The optional generation schema constraining output structure.
    ///   - generationOptions: Options controlling generation parameters.
    ///   - contextOptions: Options controlling context management limits.
    ///   - metadata: Arbitrary metadata associated with the request.
    public init(
      id: UUID,
      transcript: Transcript,
      enabledTools: [Transcript.ToolDefinition],
      schema: GenerationSchema? = nil,
      generationOptions: GenerationOptions,
      contextOptions: ContextOptions,
      metadata: [String: any ConvertibleToGeneratedContent]
    ) {
      self.id = id
      self.transcript = transcript
      self.enabledToolDefinitions = enabledTools
      self.schema = schema
      self.generationOptions = generationOptions
      self.contextOptions = contextOptions
      self.metadata = metadata.mapValues(\.generatedContent)
    }
  }
#endif  // compiler(>=6.4)
