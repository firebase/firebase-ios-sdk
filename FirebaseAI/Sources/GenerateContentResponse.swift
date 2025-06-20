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

import Foundation

/// The model's response to a generate content request.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct GenerateContentResponse: Sendable {
  /// Token usage metadata for processing the generate content request.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  public struct UsageMetadata: Sendable {
    /// The number of tokens in the request prompt.
    public let promptTokenCount: Int

    /// The total number of tokens across the generated response candidates.
    public let candidatesTokenCount: Int

    /// The number of tokens used by the model's internal "thinking" process.
    ///
    /// For models that support thinking (like Gemini 2.5 Pro and Flash), this represents the actual
    /// number of tokens consumed for reasoning before the model generated a response. For models
    /// that do not support thinking, this value will be `0`.
    ///
    /// When thinking is used, this count will be less than or equal to the `thinkingBudget` set in
    /// the ``ThinkingConfig``.
    public let thoughtsTokenCount: Int

    /// The total number of tokens in both the request and response.
    public let totalTokenCount: Int

    /// The breakdown, by modality, of how many tokens are consumed by the prompt
    public let promptTokensDetails: [ModalityTokenCount]

    /// The breakdown, by modality, of how many tokens are consumed by the candidates
    public let candidatesTokensDetails: [ModalityTokenCount]
  }

  /// A list of candidate response content, ordered from best to worst.
  public let candidates: [Candidate]

  /// A value containing the safety ratings for the response, or, if the request was blocked, a
  /// reason for blocking the request.
  public let promptFeedback: PromptFeedback?

  /// Token usage metadata for processing the generate content request.
  public let usageMetadata: UsageMetadata?

  /// The response's content as text, if it exists.
  public var text: String? {
    guard let candidate = candidates.first else {
      AILog.error(
        code: .generateContentResponseNoCandidates,
        "Could not get text from a response that had no candidates."
      )
      return nil
    }
    let textValues: [String] = candidate.content.parts.compactMap { part in
      switch part {
      case let textPart as TextPart:
        return textPart.text
      default:
        return nil
      }
    }
    guard textValues.count > 0 else {
      AILog.error(
        code: .generateContentResponseNoText,
        "Could not get a text part from the first candidate."
      )
      return nil
    }
    return textValues.joined(separator: " ")
  }

  /// Returns function calls found in any `Part`s of the first candidate of the response, if any.
  public var functionCalls: [FunctionCallPart] {
    guard let candidate = candidates.first else {
      return []
    }
    return candidate.content.parts.compactMap { part in
      switch part {
      case let functionCallPart as FunctionCallPart:
        return functionCallPart
      default:
        return nil
      }
    }
  }

  /// Returns inline data parts found in any `Part`s of the first candidate of the response, if any.
  public var inlineDataParts: [InlineDataPart] {
    guard let candidate = candidates.first else {
      AILog.error(code: .generateContentResponseNoCandidates, """
      Could not get inline data parts because the response has no candidates. The accessor only \
      checks the first candidate.
      """)
      return []
    }
    return candidate.content.parts.compactMap { $0 as? InlineDataPart }
  }

  /// Initializer for SwiftUI previews or tests.
  public init(candidates: [Candidate], promptFeedback: PromptFeedback? = nil,
              usageMetadata: UsageMetadata? = nil) {
    self.candidates = candidates
    self.promptFeedback = promptFeedback
    self.usageMetadata = usageMetadata
  }
}

/// A struct representing a possible reply to a content generation prompt. Each content generation
/// prompt may produce multiple candidate responses.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct Candidate: Sendable {
  /// The response's content.
  public let content: ModelContent

  /// The safety rating of the response content.
  public let safetyRatings: [SafetyRating]

  /// The reason the model stopped generating content, if it exists; for example, if the model
  /// generated a predefined stop sequence.
  public let finishReason: FinishReason?

  /// Cited works in the model's response content, if it exists.
  public let citationMetadata: CitationMetadata?

  /// Initializer for SwiftUI previews or tests.
  public init(content: ModelContent, safetyRatings: [SafetyRating], finishReason: FinishReason?,
              citationMetadata: CitationMetadata?) {
    self.content = content
    self.safetyRatings = safetyRatings
    self.finishReason = finishReason
    self.citationMetadata = citationMetadata
  }
}

/// A collection of source attributions for a piece of content.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct CitationMetadata: Sendable {
  /// A list of individual cited sources and the parts of the content to which they apply.
  public let citations: [Citation]
}

/// A struct describing a source attribution.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct Citation: Sendable, Equatable {
  /// The inclusive beginning of a sequence in a model response that derives from a cited source.
  public let startIndex: Int

  /// The exclusive end of a sequence in a model response that derives from a cited source.
  public let endIndex: Int

  /// A link to the cited source, if available.
  public let uri: String?

  /// The title of the cited source, if available.
  public let title: String?

  /// The license the cited source work is distributed under, if specified.
  public let license: String?

  /// The publication date of the cited source, if available.
  ///
  /// > Tip: `DateComponents` can be converted to a `Date` using the `date` computed property.
  public let publicationDate: DateComponents?

  init(startIndex: Int,
       endIndex: Int,
       uri: String? = nil,
       title: String? = nil,
       license: String? = nil,
       publicationDate: DateComponents? = nil) {
    self.startIndex = startIndex
    self.endIndex = endIndex
    self.uri = uri
    self.title = title
    self.license = license
    self.publicationDate = publicationDate
  }
}

/// A value enumerating possible reasons for a model to terminate a content generation request.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FinishReason: DecodableProtoEnum, Hashable, Sendable {
  enum Kind: String {
    case stop = "STOP"
    case maxTokens = "MAX_TOKENS"
    case safety = "SAFETY"
    case recitation = "RECITATION"
    case other = "OTHER"
    case blocklist = "BLOCKLIST"
    case prohibitedContent = "PROHIBITED_CONTENT"
    case spii = "SPII"
    case malformedFunctionCall = "MALFORMED_FUNCTION_CALL"
  }

  /// Natural stop point of the model or provided stop sequence.
  public static let stop = FinishReason(kind: .stop)

  /// The maximum number of tokens as specified in the request was reached.
  public static let maxTokens = FinishReason(kind: .maxTokens)

  /// The token generation was stopped because the response was flagged for safety reasons.
  ///
  /// > NOTE: When streaming, the ``Candidate/content`` will be empty if content filters blocked the
  /// > output.
  public static let safety = FinishReason(kind: .safety)

  /// The token generation was stopped because the response was flagged for unauthorized citations.
  public static let recitation = FinishReason(kind: .recitation)

  /// All other reasons that stopped token generation.
  public static let other = FinishReason(kind: .other)

  /// Token generation was stopped because the response contained forbidden terms.
  public static let blocklist = FinishReason(kind: .blocklist)

  /// Token generation was stopped because the response contained potentially prohibited content.
  public static let prohibitedContent = FinishReason(kind: .prohibitedContent)

  /// Token generation was stopped because of Sensitive Personally Identifiable Information (SPII).
  public static let spii = FinishReason(kind: .spii)

  /// Token generation was stopped because the function call generated by the model was invalid.
  public static let malformedFunctionCall = FinishReason(kind: .malformedFunctionCall)

  /// Returns the raw string representation of the `FinishReason` value.
  ///
  /// > Note: This value directly corresponds to the values in the [REST
  /// > API](https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/GenerateContentResponse#FinishReason).
  public let rawValue: String

  static let unrecognizedValueMessageCode =
    AILog.MessageCode.generateContentResponseUnrecognizedFinishReason
}

/// A metadata struct containing any feedback the model had on the prompt it was provided.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct PromptFeedback: Sendable {
  /// A type describing possible reasons to block a prompt.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  public struct BlockReason: DecodableProtoEnum, Hashable, Sendable {
    enum Kind: String {
      case safety = "SAFETY"
      case other = "OTHER"
      case blocklist = "BLOCKLIST"
      case prohibitedContent = "PROHIBITED_CONTENT"
    }

    /// The prompt was blocked because it was deemed unsafe.
    public static let safety = BlockReason(kind: .safety)

    /// All other block reasons.
    public static let other = BlockReason(kind: .other)

    /// The prompt was blocked because it contained terms from the terminology blocklist.
    public static let blocklist = BlockReason(kind: .blocklist)

    /// The prompt was blocked due to prohibited content.
    public static let prohibitedContent = BlockReason(kind: .prohibitedContent)

    /// Returns the raw string representation of the `BlockReason` value.
    ///
    /// > Note: This value directly corresponds to the values in the [REST
    /// > API](https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/GenerateContentResponse#BlockedReason).
    public let rawValue: String

    static let unrecognizedValueMessageCode =
      AILog.MessageCode.generateContentResponseUnrecognizedBlockReason
  }

  /// The reason a prompt was blocked, if it was blocked.
  public let blockReason: BlockReason?

  /// A human-readable description of the ``blockReason``.
  public let blockReasonMessage: String?

  /// The safety ratings of the prompt.
  public let safetyRatings: [SafetyRating]

  /// Initializer for SwiftUI previews or tests.
  public init(blockReason: BlockReason?, blockReasonMessage: String? = nil,
              safetyRatings: [SafetyRating]) {
    self.blockReason = blockReason
    self.blockReasonMessage = blockReasonMessage
    self.safetyRatings = safetyRatings
  }
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension GenerateContentResponse: Decodable {
  enum CodingKeys: CodingKey {
    case candidates
    case promptFeedback
    case usageMetadata
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard container.contains(CodingKeys.candidates) || container
      .contains(CodingKeys.promptFeedback) else {
      let context = DecodingError.Context(
        codingPath: [],
        debugDescription: "Failed to decode GenerateContentResponse;" +
          " missing keys 'candidates' and 'promptFeedback'."
      )
      throw DecodingError.dataCorrupted(context)
    }

    if let candidates = try container.decodeIfPresent(
      [Candidate].self,
      forKey: .candidates
    ) {
      self.candidates = candidates
    } else {
      candidates = []
    }
    promptFeedback = try container.decodeIfPresent(PromptFeedback.self, forKey: .promptFeedback)
    usageMetadata = try container.decodeIfPresent(UsageMetadata.self, forKey: .usageMetadata)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension GenerateContentResponse.UsageMetadata: Decodable {
  enum CodingKeys: CodingKey {
    case promptTokenCount
    case candidatesTokenCount
    case thoughtsTokenCount
    case totalTokenCount
    case promptTokensDetails
    case candidatesTokensDetails
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    promptTokenCount = try container.decodeIfPresent(Int.self, forKey: .promptTokenCount) ?? 0
    candidatesTokenCount =
      try container.decodeIfPresent(Int.self, forKey: .candidatesTokenCount) ?? 0
    thoughtsTokenCount = try container.decodeIfPresent(Int.self, forKey: .thoughtsTokenCount) ?? 0
    totalTokenCount = try container.decodeIfPresent(Int.self, forKey: .totalTokenCount) ?? 0
    promptTokensDetails =
      try container.decodeIfPresent([ModalityTokenCount].self, forKey: .promptTokensDetails) ?? []
    candidatesTokensDetails = try container.decodeIfPresent(
      [ModalityTokenCount].self,
      forKey: .candidatesTokensDetails
    ) ?? []
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Candidate: Decodable {
  enum CodingKeys: CodingKey {
    case content
    case safetyRatings
    case finishReason
    case citationMetadata
  }

  /// Initializes a response from a decoder. Used for decoding server responses; not for public
  /// use.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    do {
      if let content = try container.decodeIfPresent(ModelContent.self, forKey: .content) {
        self.content = content
      } else {
        content = ModelContent(parts: [])
      }
    } catch {
      throw InvalidCandidateError.malformedContent(underlyingError: error)
    }

    if let safetyRatings = try container.decodeIfPresent(
      [SafetyRating].self, forKey: .safetyRatings
    ) {
      self.safetyRatings = safetyRatings.filter {
        // Due to a bug in the backend, the SDK may receive invalid `SafetyRating` values that do
        // not include a category or probability; these are filtered out of the safety ratings.
        $0.category != HarmCategory.unspecified
          && $0.probability != SafetyRating.HarmProbability.unspecified
      }
    } else {
      safetyRatings = []
    }

    finishReason = try container.decodeIfPresent(FinishReason.self, forKey: .finishReason)

    // The `content` may only be empty if a `finishReason` is included; if neither are included in
    // the response then this is likely the `"content": {}` bug.
    guard !content.parts.isEmpty || finishReason != nil else {
      throw InvalidCandidateError.emptyContent(underlyingError: DecodingError.dataCorrupted(.init(
        codingPath: [CodingKeys.content, CodingKeys.finishReason],
        debugDescription: "Invalid Candidate: empty content and no finish reason"
      )))
    }

    citationMetadata = try container.decodeIfPresent(
      CitationMetadata.self,
      forKey: .citationMetadata
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension CitationMetadata: Decodable {
  enum CodingKeys: CodingKey {
    case citations // Vertex AI
    case citationSources // Google AI
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // Decode for Google API if `citationSources` key is present.
    if container.contains(.citationSources) {
      citations = try container.decode([Citation].self, forKey: .citationSources)
    } else { // Fallback to default Vertex AI decoding.
      citations = try container.decode([Citation].self, forKey: .citations)
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Citation: Decodable {
  enum CodingKeys: CodingKey {
    case startIndex
    case endIndex
    case uri
    case title
    case license
    case publicationDate
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    startIndex = try container.decodeIfPresent(Int.self, forKey: .startIndex) ?? 0
    endIndex = try container.decode(Int.self, forKey: .endIndex)

    if let uri = try container.decodeIfPresent(String.self, forKey: .uri), !uri.isEmpty {
      self.uri = uri
    } else {
      uri = nil
    }

    if let title = try container.decodeIfPresent(String.self, forKey: .title), !title.isEmpty {
      self.title = title
    } else {
      title = nil
    }

    if let license = try container.decodeIfPresent(String.self, forKey: .license),
       !license.isEmpty {
      self.license = license
    } else {
      license = nil
    }

    if let publicationProtoDate = try container.decodeIfPresent(
      ProtoDate.self,
      forKey: .publicationDate
    ) {
      publicationDate = publicationProtoDate.dateComponents
      if let publicationDate, !publicationDate.isValidDate {
        AILog.warning(
          code: .decodedInvalidCitationPublicationDate,
          "Decoded an invalid citation publication date: \(publicationDate)"
        )
      }
    } else {
      publicationDate = nil
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension PromptFeedback: Decodable {
  enum CodingKeys: CodingKey {
    case blockReason
    case blockReasonMessage
    case safetyRatings
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    blockReason = try container.decodeIfPresent(
      PromptFeedback.BlockReason.self,
      forKey: .blockReason
    )
    blockReasonMessage = try container.decodeIfPresent(String.self, forKey: .blockReasonMessage)
    if let safetyRatings = try container.decodeIfPresent(
      [SafetyRating].self,
      forKey: .safetyRatings
    ) {
      self.safetyRatings = safetyRatings
    } else {
      safetyRatings = []
    }
  }
}
