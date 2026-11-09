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

  #if canImport(FoundationInternationalization)
    import FoundationInternationalization
  #endif

  /// Errors that can occur during language model interactions.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`LanguageModelError`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror).
  @nonexhaustive
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public enum LanguageModelError: LocalizedError {
    /// The transcript exceeded the model's context size limit.
    case contextSizeExceeded(LanguageModelError.ContextSizeExceeded)

    /// The request was rate limited.
    case rateLimited(LanguageModelError.RateLimited)

    /// A safety guardrail was triggered.
    case guardrailViolation(LanguageModelError.GuardrailViolation)

    /// The model refused to answer the prompt.
    case refusal(LanguageModelError.Refusal)

    /// A requested capability is not supported by the model.
    case unsupportedCapability(LanguageModelError.UnsupportedCapability)

    /// The prompt contains transcript content that the model cannot process.
    case unsupportedTranscriptContent(LanguageModelError.UnsupportedTranscriptContent)

    /// An unsupported generation guide was provided.
    case unsupportedGenerationGuide(LanguageModelError.UnsupportedGenerationGuide)

    /// The model was prompted to respond in an unsupported language or locale.
    case unsupportedLanguageOrLocale(LanguageModelError.UnsupportedLanguageOrLocale)

    /// The request timed out.
    case timeout(LanguageModelError.Timeout)
  }

  extension LanguageModelError {
    /// Payload describing a context size exceeded error.
    ///
    /// - SeeAlso: [`LanguageModelError.ContextSizeExceeded`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/contextsizeexceeded)
    public struct ContextSizeExceeded: Sendable {
      /// The maximum context size allowed by the model.
      public var contextSize: Int

      /// The number of tokens that exceeded the context size limit.
      public var tokenCount: Int

      /// A developer-facing description of the error.
      public var debugDescription: String

      /// Additional metadata associated with the error.
      public var metadata: [String: any Sendable]

      /// Creates a context-size-exceeded error payload.
      ///
      /// - Parameters:
      ///   - contextSize: The maximum token limit of the model.
      ///   - tokenCount: The token count that exceeded the limit.
      ///   - debugDescription: A developer-facing description of the error.
      ///   - metadata: Additional metadata associated with the error.
      public init(
        contextSize: Int,
        tokenCount: Int,
        debugDescription: String,
        metadata: [String: any Sendable] = [:]
      ) {
        self.contextSize = contextSize
        self.tokenCount = tokenCount
        self.debugDescription = debugDescription
        self.metadata = metadata
      }
    }
  }

  extension LanguageModelError {
    /// Payload describing a rate-limiting error.
    ///
    /// - SeeAlso: [`LanguageModelError.RateLimited`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/ratelimited)
    public struct RateLimited: Sendable {
      /// The date and time when the rate limit resets, or `nil` if unknown.
      public var resetDate: Date?

      /// A developer-facing description of the error.
      public var debugDescription: String

      /// Additional metadata associated with the error.
      public var metadata: [String: any Sendable]

      /// Creates a rate-limited error payload.
      ///
      /// - Parameters:
      ///   - resetDate: The date and time when the rate limit resets, or `nil`.
      ///   - debugDescription: A developer-facing description of the error.
      ///   - metadata: Additional metadata associated with the error.
      public init(
        resetDate: Date?, debugDescription: String, metadata: [String: any Sendable] = [:]
      ) {
        self.resetDate = resetDate
        self.debugDescription = debugDescription
        self.metadata = metadata
      }
    }
  }

  extension LanguageModelError {
    /// Payload describing a safety guardrail violation error.
    ///
    /// - SeeAlso: [`LanguageModelError.GuardrailViolation`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/guardrailviolation)
    public struct GuardrailViolation: Sendable {
      /// A developer-facing description of the error.
      public var debugDescription: String

      /// Additional metadata associated with the error.
      public var metadata: [String: any Sendable]

      /// Creates a guardrail-violation error payload.
      ///
      /// - Parameters:
      ///   - debugDescription: A developer-facing description of the error.
      ///   - metadata: Additional metadata associated with the error.
      public init(debugDescription: String, metadata: [String: any Sendable] = [:]) {
        self.debugDescription = debugDescription
        self.metadata = metadata
      }
    }
  }

  extension LanguageModelError {
    /// Payload describing a model refusal error.
    ///
    /// - SeeAlso: [`LanguageModelError.Refusal`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/refusal)
    public struct Refusal: Sendable {
      /// A developer-facing description of the error.
      public var debugDescription: String

      /// Additional metadata associated with the error.
      public var metadata: [String: any Sendable]

      /// The model's explanation for why it refused to respond, as provided at creation.
      var explanationText: String

      /// Creates a refusal error payload.
      ///
      /// - Parameters:
      ///   - explanation: The model's explanation for refusing to respond.
      ///   - debugDescription: A developer-facing description of the error.
      ///   - metadata: Additional metadata associated with the error.
      public init(
        explanation: String,
        debugDescription: String,
        metadata: [String: any Sendable] = [:]
      ) {
        self.explanationText = explanation
        self.debugDescription = debugDescription
        self.metadata = metadata
      }
    }
  }

  extension LanguageModelError {
    /// Payload describing an unsupported capability error.
    ///
    /// - SeeAlso: [`LanguageModelError.UnsupportedCapability`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/unsupportedcapability)
    public struct UnsupportedCapability: Sendable {
      /// The capability that is not supported.
      public var capability: LanguageModelCapabilities.Capability

      /// A developer-facing description of the error.
      public var debugDescription: String

      /// Additional metadata associated with the error.
      public var metadata: [String: any Sendable]

      /// Creates an unsupported-capability error payload.
      ///
      /// - Parameters:
      ///   - capability: The unsupported capability.
      ///   - debugDescription: A developer-facing description of the error.
      ///   - metadata: Additional metadata associated with the error.
      public init(
        capability: LanguageModelCapabilities.Capability,
        debugDescription: String,
        metadata: [String: any Sendable] = [:]
      ) {
        self.capability = capability
        self.debugDescription = debugDescription
        self.metadata = metadata
      }
    }
  }

  extension LanguageModelError {
    /// Payload describing an unsupported transcript content error.
    ///
    /// - SeeAlso: [`LanguageModelError.UnsupportedTranscriptContent`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/unsupportedtranscriptcontent)
    public struct UnsupportedTranscriptContent: Sendable {
      /// The transcript entries that are not supported.
      public var unsupportedContent: [Transcript.Entry]

      /// A developer-facing description of the error.
      public var debugDescription: String

      /// Additional metadata associated with the error.
      public var metadata: [String: any Sendable]

      /// Creates an unsupported-transcript-content error payload.
      ///
      /// - Parameters:
      ///   - unsupportedContent: The unsupported transcript entries.
      ///   - debugDescription: A developer-facing description of the error.
      ///   - metadata: Additional metadata associated with the error.
      public init(
        unsupportedContent: [Transcript.Entry],
        debugDescription: String,
        metadata: [String: any Sendable] = [:]
      ) {
        self.unsupportedContent = unsupportedContent
        self.debugDescription = debugDescription
        self.metadata = metadata
      }
    }
  }

  extension LanguageModelError {
    /// Payload describing an unsupported generation guide error.
    ///
    /// - SeeAlso: [`LanguageModelError.UnsupportedGenerationGuide`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/unsupportedgenerationguide)
    public struct UnsupportedGenerationGuide: Sendable {
      /// The name of the unsupported schema, or `nil` if unnamed.
      public var schemaName: String?

      /// A developer-facing description of the error.
      public var debugDescription: String

      /// Additional metadata associated with the error.
      public var metadata: [String: any Sendable]

      /// Creates an unsupported-generation-guide error payload.
      ///
      /// - Parameters:
      ///   - schemaName: The name of the unsupported schema, or `nil`.
      ///   - debugDescription: A developer-facing description of the error.
      ///   - metadata: Additional metadata associated with the error.
      public init(
        schemaName: String?,
        debugDescription: String,
        metadata: [String: any Sendable] = [:]
      ) {
        self.schemaName = schemaName
        self.debugDescription = debugDescription
        self.metadata = metadata
      }
    }
  }

  extension LanguageModelError {
    /// Payload describing an unsupported language or locale error.
    ///
    /// - SeeAlso: [`LanguageModelError.UnsupportedLanguageOrLocale`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/unsupportedlanguageorlocale)
    public struct UnsupportedLanguageOrLocale: Sendable {
      /// The unsupported language code.
      public var languageCode: Locale.LanguageCode

      /// A developer-facing description of the error.
      public var debugDescription: String

      /// Additional metadata associated with the error.
      public var metadata: [String: any Sendable]

      /// Creates an unsupported-language-or-locale error payload.
      ///
      /// - Parameters:
      ///   - languageCode: The unsupported language code.
      ///   - debugDescription: A developer-facing description of the error.
      ///   - metadata: Additional metadata associated with the error.
      public init(
        languageCode: Locale.LanguageCode,
        debugDescription: String,
        metadata: [String: any Sendable] = [:]
      ) {
        self.languageCode = languageCode
        self.debugDescription = debugDescription
        self.metadata = metadata
      }
    }
  }

  extension LanguageModelError {
    /// Payload describing a request timeout error.
    ///
    /// - SeeAlso: [`LanguageModelError.Timeout`](https://developer.apple.com/documentation/foundationmodels/languagemodelerror/timeout)
    public struct Timeout: Sendable {
      /// A developer-facing description of the error.
      public var debugDescription: String

      /// Additional metadata associated with the error.
      public var metadata: [String: any Sendable]

      /// Creates a timeout error payload.
      ///
      /// - Parameters:
      ///   - debugDescription: A developer-facing description of the error.
      ///   - metadata: Additional metadata associated with the error.
      public init(debugDescription: String, metadata: [String: any Sendable] = [:]) {
        self.debugDescription = debugDescription
        self.metadata = metadata
      }
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension LanguageModelError: CustomDebugStringConvertible {
    /// A developer-facing description of the error suitable for debugging.
    public var debugDescription: String {
      switch self {
      case .contextSizeExceeded(let payload):
        payload.debugDescription
      case .rateLimited(let payload):
        payload.debugDescription
      case .guardrailViolation(let payload):
        payload.debugDescription
      case .refusal(let payload):
        payload.debugDescription
      case .unsupportedCapability(let payload):
        payload.debugDescription
      case .unsupportedTranscriptContent(let payload):
        payload.debugDescription
      case .unsupportedGenerationGuide(let payload):
        payload.debugDescription
      case .unsupportedLanguageOrLocale(let payload):
        payload.debugDescription
      case .timeout(let payload):
        payload.debugDescription
      }
    }
  }

  extension LanguageModelError {
    /// A localized description of the error.
    public var errorDescription: String? {
      switch self {
      case .contextSizeExceeded:
        "The transcript is too long for the model's context."
      case .rateLimited:
        "The model rate limited the session."
      case .guardrailViolation:
        "The model's guardrails blocked the request."
      case .refusal:
        "The model declined to respond."
      case .unsupportedCapability:
        "The model lacks a capability the request needs."
      case .unsupportedTranscriptContent:
        "The transcript contains content the model can't handle."
      case .unsupportedGenerationGuide:
        "The model can't apply one of the generation guides."
      case .unsupportedLanguageOrLocale:
        "The model doesn't support the requested language or locale."
      case .timeout:
        "The model didn't respond in time."
      }
    }

    /// A localized explanation of the reason for the failure.
    public var failureReason: String? {
      nil
    }

    /// A localized suggestion for recovering from the error.
    public var recoverySuggestion: String? {
      switch self {
      case .contextSizeExceeded:
        "Shorten the transcript, then retry."
      case .rateLimited(let payload):
        if let resetDate = payload.resetDate {
          "Retry after \(resetDate.formatted(date: .numeric, time: .complete))."
        } else {
          "Retry later."
        }
      case .guardrailViolation:
        "Change the prompt, then retry."
      case .refusal:
        nil
      case .unsupportedCapability(let payload):
        switch payload.capability.kind {
        case .vision:
          "Use a model that accepts images."
        case .guidedGeneration:
          "Use a model that supports guided generation."
        case .reasoning:
          "Use a model that supports reasoning."
        case .toolCalling:
          "Use a model that supports tool calling."
        }
      case .unsupportedTranscriptContent:
        "Remove the content, or use a model that accepts it."
      case .unsupportedGenerationGuide:
        "Change the guide, or use a model that supports it."
      case .unsupportedLanguageOrLocale:
        "Use a language or locale the model supports."
      case .timeout:
        "Retry in a few seconds."
      }
    }
  }

  extension LanguageModelError.Refusal {
    /// The model's refusal response containing the explanation text.
    nonisolated(nonsending) public var explanation: LanguageModelSession.Response<String> {
      get async throws {
        let emptyEntries: [Transcript.Entry] = []
        return LanguageModelSession.Response(
          content: explanationText,
          rawContent: GeneratedContent(explanationText),
          transcriptEntries: emptyEntries[...],
          usage: .zero
        )
      }
    }

    /// A stream yielding the model's refusal response.
    public var explanationStream: LanguageModelSession.ResponseStream<String> {
      let emptyEntries: [Transcript.Entry] = []
      let response = LanguageModelSession.Response(
        content: explanationText,
        rawContent: GeneratedContent(explanationText),
        transcriptEntries: emptyEntries[...],
        usage: .zero
      )
      return LanguageModelSession.ResponseStream(
        resolved: response,
        snapshotContent: explanationText
      )
    }
  }
#endif  // compiler(>=6.4)
