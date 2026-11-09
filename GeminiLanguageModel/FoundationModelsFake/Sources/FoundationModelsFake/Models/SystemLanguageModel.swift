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
  public import Foundation
  public import Observation
  import Synchronization

  /// A fake system language model that is always unavailable.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`SystemLanguageModel`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel).
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  public final class SystemLanguageModel: Sendable {
    // MARK: - Internal Representation

    /// Describes how a `SystemLanguageModel` instance was configured.
    internal enum Source: Hashable, Sendable {
      /// Standard system model configured with a use case and guardrails.
      case standard(useCase: UseCase.Kind, guardrails: Guardrails.Kind, isDefaultSingleton: Bool)
    }

    /// The configuration source for this model instance.
    internal let source: Source

    /// Observation registrar matching Apple's `Observable` conformance on `SystemLanguageModel`.
    internal let observationRegistrar = ObservationRegistrar()

    // MARK: - Default Instance

    /// The default system language model instance.
    public static let `default` = SystemLanguageModel(
      useCase: .general,
      guardrails: .default,
      isDefaultSingleton: true
    )

    // MARK: - Initializers

    /// Creates an internal system language model instance.
    internal init(source: Source) {
      self.source = source
    }

    /// Creates a system language model for a specific use case, optionally distinguished by
    /// whether it is the static `.default` singleton.
    internal convenience init(
      useCase: SystemLanguageModel.UseCase,
      guardrails: SystemLanguageModel.Guardrails,
      isDefaultSingleton: Bool
    ) {
      self.init(
        source: .standard(
          useCase: useCase.kind,
          guardrails: guardrails.kind,
          isDefaultSingleton: isDefaultSingleton
        )
      )
    }

    /// Creates a system language model with the specified use case and guardrails.
    ///
    /// - Parameters:
    ///   - useCase: The intended use case for the model.
    ///   - guardrails: The safety guardrails configuration.
    public convenience init(
      useCase: SystemLanguageModel.UseCase = .general,
      guardrails: SystemLanguageModel.Guardrails = .default
    ) {
      self.init(useCase: useCase, guardrails: guardrails, isDefaultSingleton: false)
    }

    // MARK: - Availability & Locale Support

    /// The availability status of the model, which is always unavailable in this fake.
    public final var availability: SystemLanguageModel.Availability {
      observationRegistrar.access(self, keyPath: \.availability)
      return .unavailable(.deviceNotEligible)
    }

    /// Whether the model is available, which is always `false` in this fake.
    public final var isAvailable: Bool {
      observationRegistrar.access(self, keyPath: \.isAvailable)
      return false
    }

    /// The set of supported languages, which is always empty in this fake.
    public final var supportedLanguages: Set<Locale.Language> {
      observationRegistrar.access(self, keyPath: \.supportedLanguages)
      return []
    }

    /// Returns whether the model supports the specified locale, returning `false` in this fake.
    ///
    /// - Parameter locale: The locale to test.
    /// - Returns: `false` in this fake implementation.
    public final func supportsLocale(_ locale: Locale = Locale.current) -> Bool {
      false
    }

    // MARK: - Context Size, Variant, and Token Counting

    /// The maximum context size supported by the model, returning 4096 in this fake.
    public final var contextSize: Int {
      observationRegistrar.access(self, keyPath: \.contextSize)
      return 4096
    }

    /// The model variant, which defaults to ``Variant/core3`` in this fake.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public final var variant: SystemLanguageModel.Variant {
      observationRegistrar.access(self, keyPath: \.variant)
      return .core3
    }

    /// Estimates the number of tokens required to represent the given prompt.
    ///
    /// - Parameter prompt: The prompt whose tokens are counted.
    /// - Returns: The estimated token count.
    /// - Throws: An error if token estimation fails.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func tokenCount(
      for prompt: some PromptRepresentable
    ) async throws -> Int {
      let segments = prompt.promptRepresentation.segments
      return Self.estimateTokenCount(forSegments: segments)
    }

    /// Estimates the number of tokens required to represent the given instructions.
    ///
    /// - Parameter instructions: The instructions whose tokens are counted.
    /// - Returns: The estimated token count.
    /// - Throws: An error if token estimation fails.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func tokenCount(
      for instructions: Instructions
    ) async throws -> Int {
      Self.estimateTokenCount(forSegments: instructions.segments)
    }

    /// Estimates the number of tokens required to represent the definitions of the given tools.
    ///
    /// - Parameter tools: The tools whose schema definitions are counted.
    /// - Returns: The estimated token count, or 0 if `tools` is empty.
    /// - Throws: An error if token estimation fails.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func tokenCount(
      for tools: [any Tool]
    ) async throws -> Int {
      guard !tools.isEmpty else { return 0 }
      var total = 0
      for tool in tools {
        let definition = Transcript.ToolDefinition(tool: tool)
        total += Self.estimateTokenCount(forToolDefinition: definition)
      }
      return max(1, total)
    }

    /// Estimates the number of tokens required to represent the given generation schema.
    ///
    /// - Parameter schema: The generation schema whose tokens are counted.
    /// - Returns: The estimated token count.
    /// - Throws: An error if token estimation fails.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func tokenCount(
      for schema: GenerationSchema
    ) async throws -> Int {
      Self.estimateTokenCount(forSchema: schema)
    }

    /// Estimates the number of tokens required to represent the given transcript entries.
    ///
    /// - Parameter entries: The transcript entries whose tokens are counted.
    /// - Returns: The estimated token count, or 0 if `entries` is empty.
    /// - Throws: An error if token estimation fails.
    @available(iOS 26.4, macOS 26.4, visionOS 26.4, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    nonisolated(nonsending) public final func tokenCount(
      for entries: some Collection<Transcript.Entry>
    ) async throws -> Int {
      guard !entries.isEmpty else { return 0 }
      var total = 0
      for entry in entries {
        switch entry {
        case .instructions(let instructions):
          total += Self.estimateTokenCount(forSegments: instructions.segments)
          for toolDef in instructions.toolDefinitions {
            total += Self.estimateTokenCount(forToolDefinition: toolDef)
          }
        case .prompt(let prompt):
          total += Self.estimateTokenCount(forSegments: prompt.segments)
          if case .schema(let schema) = prompt.responseFormat?.kind {
            total += Self.estimateTokenCount(forSchema: schema)
          }
        case .reasoning(let reasoning):
          total += Self.estimateTokenCount(forSegments: reasoning.segments)
        case .toolCalls(let toolCalls):
          for call in toolCalls {
            total += Self.estimateTokenCount(forText: call.toolName)
            total += Self.estimateTokenCount(forText: call.arguments.jsonString)
          }
        case .toolOutput(let toolOutput):
          total += Self.estimateTokenCount(forText: toolOutput.toolName)
          total += Self.estimateTokenCount(forSegments: toolOutput.segments)
        case .response(let response):
          total += Self.estimateTokenCount(forSegments: response.segments)
        #if compiler(>=6.4.2)
          case .data(let dataEntry):
            total += max(1, (dataEntry.content.count + 3) / 4)
        #endif  // compiler(>=6.4.2)
        }
      }
      return max(1, total)
    }

    // MARK: - LanguageModel Conformance

    /// The capabilities supported by the system language model in this fake.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public var capabilities: LanguageModelCapabilities {
      LanguageModelCapabilities([.guidedGeneration, .toolCalling, .reasoning])
    }

    /// The executor configuration for this system language model.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public var executorConfiguration: SystemLanguageModel.Executor.Configuration {
      Executor.Configuration(source: source)
    }
  }

  // MARK: - Observable Conformance

  extension SystemLanguageModel: nonisolated Observable {}

  // MARK: - LanguageModel Conformance

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
  @available(watchOS, unavailable)
  @available(tvOS, unavailable)
  extension SystemLanguageModel: LanguageModel {}

  // MARK: - Availability

  extension SystemLanguageModel {
    /// The availability status of a system language model.
    ///
    /// - SeeAlso: [`SystemLanguageModel.Availability`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability)
    @frozen
    public enum Availability: Sendable, Equatable {
      /// The model is ready for use.
      case available

      /// The model is unavailable for the specified reason.
      case unavailable(SystemLanguageModel.Availability.UnavailableReason)

      /// Reasons why a system language model may be unavailable.
      ///
      /// - SeeAlso: [`SystemLanguageModel.Availability.UnavailableReason`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability/unavailablereason)
      public enum UnavailableReason: Sendable, Equatable, Hashable {
        /// The device does not support the model.
        case deviceNotEligible

        /// Apple Intelligence features are not enabled on the device.
        case appleIntelligenceNotEnabled

        /// The model assets are not downloaded or prepared for execution.
        case modelNotReady
      }
    }
  }

  // MARK: - UseCase

  extension SystemLanguageModel {
    /// The intended use case for a system language model.
    ///
    /// - SeeAlso: [`SystemLanguageModel.UseCase`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/usecase)
    public struct UseCase: Sendable, Equatable {
      /// Internal identifier of the use case.
      internal enum Kind: String, Sendable, Equatable, Hashable {
        case general
        case contentTagging
      }

      /// The underlying kind of use case.
      internal let kind: Kind

      /// Creates a use case wrapping `kind`.
      internal init(_ kind: Kind) {
        self.kind = kind
      }

      /// A general-purpose language modeling use case.
      public static let general = UseCase(.general)

      /// A use case tailored for content tagging and classification.
      public static let contentTagging = UseCase(.contentTagging)
    }
  }

  // MARK: - Guardrails

  extension SystemLanguageModel {
    /// Safety guardrail settings for a system language model.
    ///
    /// - SeeAlso: [`SystemLanguageModel.Guardrails`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails)
    public struct Guardrails: Sendable {
      /// Internal identifier of the guardrails mode.
      internal enum Kind: String, Sendable, Equatable, Hashable {
        case `default`
        case permissiveContentTransformations
      }

      /// The underlying kind of guardrails configuration.
      internal let kind: Kind

      /// Creates a guardrails configuration wrapping `kind`.
      internal init(_ kind: Kind) {
        self.kind = kind
      }

      /// The default safety guardrails configuration.
      public static let `default` = Guardrails(.default)

      /// A guardrails configuration allowing permissive content transformations.
      public static let permissiveContentTransformations = Guardrails(
        .permissiveContentTransformations
      )
    }
  }

  // MARK: - Variant

  extension SystemLanguageModel {
    /// A model architecture variant of the system language model.
    ///
    /// - SeeAlso: [`SystemLanguageModel.Variant`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/variant)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public struct Variant: Sendable, Equatable, Hashable {
      /// The human-readable display name of the variant.
      public let displayName: String

      /// The standard Core 3B model variant.
      public static let core3 = Variant(displayName: "Core 3B")

      /// The Core Advanced 3B model variant.
      public static let coreAdvanced3 = Variant(displayName: "Core Advanced 3B")
    }
  }

  // MARK: - Error

  extension SystemLanguageModel {
    /// Errors that can occur when interacting with the system language model.
    ///
    /// - SeeAlso: [`SystemLanguageModel.Error`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/error)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public enum Error: LocalizedError, CustomDebugStringConvertible, Sendable {
      /// Information about unavailable system language model assets.
      public struct AssetsUnavailable: Sendable {
        /// A developer-facing description of why the assets are unavailable.
        public var debugDescription: String

        /// Creates an assets-unavailable error payload.
        ///
        /// - Parameter debugDescription: A developer-facing description of the error.
        public init(debugDescription: String) {
          self.debugDescription = debugDescription
        }
      }

      /// The model assets are not available on this device.
      case assetsUnavailable(SystemLanguageModel.Error.AssetsUnavailable)

      /// A localized description of the error.
      public var errorDescription: String? {
        switch self {
        case .assetsUnavailable(let payload):
          return payload.debugDescription
        }
      }

      /// A developer-facing description of the error suitable for debugging.
      public var debugDescription: String {
        switch self {
        case .assetsUnavailable(let payload):
          return payload.debugDescription
        }
      }
    }
  }

  // MARK: - Executor

  extension SystemLanguageModel {
    /// An executor for the system language model that always throws upon execution in this fake.
    ///
    /// - SeeAlso: [`SystemLanguageModel.Executor`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/executor)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public struct Executor: LanguageModelExecutor, Sendable {
      /// The type of model associated with this executor.
      public typealias Model = SystemLanguageModel

      /// Configuration options used to initialize a system language model executor.
      public struct Configuration: Hashable, Sendable {
        /// The model source configuration.
        internal let source: SystemLanguageModel.Source
      }

      /// The configuration this executor was created with.
      internal let configuration: Configuration

      /// Creates an executor with the specified configuration.
      ///
      /// - Parameter configuration: The configuration options for the executor.
      /// - Throws: An error if initialization fails.
      public init(configuration: SystemLanguageModel.Executor.Configuration) throws {
        self.configuration = configuration
      }

      /// Prepares the executor for generation with the given model and transcript.
      ///
      /// - Parameters:
      ///   - model: The model to prewarm.
      ///   - transcript: The transcript to prepare for generation.
      public func prewarm(model: SystemLanguageModel, transcript: Transcript) {}

      /// Executes generation for a request, always throwing an error in this fake.
      ///
      /// - Parameters:
      ///   - request: The generation request to process.
      ///   - model: The model servicing the request.
      ///   - channel: The channel receiving streamed generation events.
      /// - Throws: An error unconditionally in this fake.
      nonisolated(nonsending) public func respond(
        to request: LanguageModelExecutorGenerationRequest,
        model: SystemLanguageModel,
        streamingInto channel: LanguageModelExecutorGenerationChannel
      ) async throws {
        throw SystemLanguageModel.Error.assetsUnavailable(
          .init(debugDescription: "The fake's system language model is never available.")
        )
      }
    }
  }

  // MARK: - Token Estimation Helpers

  extension SystemLanguageModel {
    /// Estimates the token count for an array of transcript segments.
    internal static func estimateTokenCount(forSegments segments: [Transcript.Segment]) -> Int {
      guard !segments.isEmpty else { return 0 }
      var total = 0
      for segment in segments {
        switch segment {
        case .text(let textSegment):
          total += estimateTokenCount(forText: textSegment.content)
        case .structure(let structuredSegment):
          total += estimateTokenCount(forText: structuredSegment.content.jsonString)
        case .attachment:
          total += 256
        }
      }
      return total
    }

    /// Estimates the token count for a tool definition.
    internal static func estimateTokenCount(
      forToolDefinition definition: Transcript.ToolDefinition
    ) -> Int {
      var total = estimateTokenCount(forText: definition.name)
      total += estimateTokenCount(forText: definition.description)
      total += estimateTokenCount(forSchema: definition.parameters)
      return max(1, total)
    }

    /// Estimates the token count for a generation schema.
    internal static func estimateTokenCount(forSchema schema: GenerationSchema) -> Int {
      if let data = try? JSONEncoder().encode(schema),
        let json = String(data: data, encoding: .utf8)
      {
        return max(1, estimateTokenCount(forText: json))
      }
      return 8
    }

    /// Estimates the token count for a plain string using a ~4 UTF-8 bytes per token heuristic.
    internal static func estimateTokenCount(forText text: String) -> Int {
      let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return 0 }
      let utf8Count = trimmed.utf8.count
      return max(1, (utf8Count + 3) / 4)
    }
  }
#endif  // compiler(>=6.4)
