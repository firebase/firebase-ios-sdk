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
    import FoundationEssentials
  #else
    import Foundation
  #endif

  extension Transcript {
    /// A prompt submitted to a language model.
    ///
    /// - SeeAlso: [`Transcript.Prompt`](https://developer.apple.com/documentation/foundationmodels/transcript/prompt)
    public struct Prompt: Sendable, Identifiable, Equatable {
      /// The unique identifier of the prompt.
      public var id: String

      /// The segments that compose the prompt.
      public var segments: [Transcript.Segment]

      /// Options controlling model output generation.
      public var options: GenerationOptions

      /// Options that specify how context is supplied to the model.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public var contextOptions: ContextOptions

      /// Metadata associated with the prompt.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public var metadata: [String: GeneratedContent]

      /// The expected format for model responses, if specified.
      public var responseFormat: Transcript.ResponseFormat?

      /// Creates a prompt with the given parameters and options.
      ///
      /// - Parameters:
      ///   - id: The unique identifier for the prompt.
      ///   - metadata: Metadata associated with the prompt.
      ///   - segments: The segments composing the prompt.
      ///   - options: Options configuring model generation.
      ///   - responseFormat: The expected response format, if any.
      ///   - contextOptions: Options governing context inclusion.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public init(
        id: String = UUID().uuidString,
        metadata: [String: any ConvertibleToGeneratedContent] = [:],
        segments: [Transcript.Segment],
        options: GenerationOptions = GenerationOptions(),
        responseFormat: Transcript.ResponseFormat? = nil,
        contextOptions: ContextOptions = ContextOptions()
      ) {
        self.id = id
        self.metadata = metadata.mapValues(\.generatedContent)
        self.segments = segments
        self.options = options
        self.responseFormat = responseFormat
        self.contextOptions = contextOptions
      }

      /// The identifier type for a prompt.
      public typealias ID = String
    }
  }

  extension Transcript.Prompt {
    /// Creates a prompt with the given segments and generation options.
    ///
    /// - Parameters:
    ///   - id: The unique identifier for the prompt.
    ///   - segments: The segments composing the prompt.
    ///   - options: Options configuring model generation.
    ///   - responseFormat: The expected response format, if any.
    public init(
      id: String = UUID().uuidString,
      segments: [Transcript.Segment],
      options: GenerationOptions = GenerationOptions(),
      responseFormat: Transcript.ResponseFormat? = nil
    ) {
      self.init(
        id: id,
        metadata: [:],
        segments: segments,
        options: options,
        responseFormat: responseFormat,
        contextOptions: responseFormat == nil
          ? ContextOptions() : ContextOptions(includeSchemaInPrompt: true)
      )
    }

    /// Returns a Boolean value indicating whether two prompts are equal.
    ///
    /// - Parameters:
    ///   - lhs: The first prompt to compare.
    ///   - rhs: The second prompt to compare.
    /// - Returns: `true` if both prompts are equal.
    public static func == (lhs: Transcript.Prompt, rhs: Transcript.Prompt) -> Bool {
      lhs.id == rhs.id
        && lhs.segments == rhs.segments
        && lhs.options == rhs.options
        && lhs.contextOptions == rhs.contextOptions
        && lhs.metadata == rhs.metadata
        && lhs.responseFormat == rhs.responseFormat
    }
  }

  extension Transcript {
    /// The schema and format requested for structured model output.
    ///
    /// - SeeAlso: [`Transcript.ResponseFormat`](https://developer.apple.com/documentation/foundationmodels/transcript/responseformat)
    public struct ResponseFormat: Sendable, Equatable {
      /// The underlying kind of the response format.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public let kind: Transcript.ResponseFormat.Kind

      /// The name decoded from a serialized transcript, which overrides the schema's type name.
      ///
      /// Transcript JSON stores the response format's name next to its schema, and a decoded
      /// schema can't always recover it (for example, `"String"` or `"Array<Int>"`).
      ///
      /// The synthesized memberwise initializer, `init(kind:decodedName:)`, sets it.
      let decodedName: String?

      /// Returns a Boolean value indicating whether two response formats are equal.
      ///
      /// - Parameters:
      ///   - a: The first response format to compare.
      ///   - b: The second response format to compare.
      /// - Returns: `true` if both response formats are equal.
      public static func == (a: Transcript.ResponseFormat, b: Transcript.ResponseFormat) -> Bool {
        a.kind == b.kind && a.name == b.name
      }
    }
  }

  extension Transcript.ResponseFormat {
    /// The display name of the response format.
    public var name: String {
      if let decodedName {
        return decodedName
      }
      switch kind {
      case .schema(let schema):
        return schema.transcriptTypeName
      }
    }

    /// Creates a response format matching the schema of a generable type.
    ///
    /// - Parameter type: The generable type to produce output for.
    public init<Content>(type: Content.Type) where Content: Generable {
      self.init(schema: Content.generationSchema)
    }

    /// Creates a response format from a generation schema.
    ///
    /// - Parameter schema: The schema defining the output structure.
    public init(schema: GenerationSchema) {
      self.init(kind: .schema(schema), decodedName: nil)
    }
  }

  extension Transcript.ResponseFormat {
    /// The representation kind of a response format.
    ///
    /// - SeeAlso: [`Transcript.ResponseFormat.Kind`](https://developer.apple.com/documentation/foundationmodels/transcript/responseformat/kind)
    @nonexhaustive
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public enum Kind: Sendable {
      /// A response format backed by a generation schema.
      case schema(GenerationSchema)
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.ResponseFormat.Kind: Equatable {
    /// Returns a Boolean value indicating whether two response format kinds are equal.
    ///
    /// - Parameters:
    ///   - lhs: The first kind to compare.
    ///   - rhs: The second kind to compare.
    /// - Returns: `true` if both kinds are equivalent.
    public static func == (
      lhs: Transcript.ResponseFormat.Kind,
      rhs: Transcript.ResponseFormat.Kind
    ) -> Bool {
      switch (lhs, rhs) {
      case (.schema(let lhs), .schema(let rhs)):
        lhs.isTranscriptEquivalent(to: rhs)
      }
    }
  }
#endif  // compiler(>=6.4)
