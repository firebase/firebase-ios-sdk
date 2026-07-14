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
import GoogleAIDataModels
import AgentPlatformDataModels

/// The model's response to a generate content request.
public struct GenerateContentResponse: Sendable {
  /// Token usage metadata for processing the generate content request.
  public struct UsageMetadata: Sendable {
    /// The number of tokens in the request prompt.
    public let promptTokenCount: Int

    /// The number of tokens in the prompt that were served from the cache.
    /// If implicit caching is not active or no content was cached, this will be 0.
    public let cachedContentTokenCount: Int

    /// The total number of tokens across the generated response candidates.
    public let candidatesTokenCount: Int

    /// The number of tokens used by tools.
    public let toolUsePromptTokenCount: Int

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

    /// The breakdown, by modality, of how many tokens are consumed by the prompt.
    public let promptTokensDetails: [ModalityTokenCount]

    /// The breakdown, by modality, of how many tokens are consumed by the cached content.
    public let cacheTokensDetails: [ModalityTokenCount]

    /// Detailed breakdown of the cached tokens by modality (e.g., text, image).
    /// This list provides granular insight into which parts of the content were cached.
    public let candidatesTokensDetails: [ModalityTokenCount]

    /// The breakdown, by modality, of how many tokens were consumed by the tools used to process
    /// the request.
    public let toolUsePromptTokensDetails: [ModalityTokenCount]
  }

  /// A list of candidate response content, ordered from best to worst.
  public let candidates: [Candidate]

  /// A value containing the safety ratings for the response, or, if the request was blocked, a
  /// reason for blocking the request.
  public let promptFeedback: PromptFeedback?

  /// Token usage metadata for processing the generate content request.
  public let usageMetadata: UsageMetadata?

  let responseID: String?

  static let unknownModelVersion = "unknown-model-version"

  /// Returns the model version used to generate the response.
  ///
  /// - Note: If the model version is not specified by the backend, this returns
  ///   "unknown-model-version".
  public let modelVersion: String

  /// The response's content as text, if it exists.
  ///
  /// - Note: This does not include thought summaries; see ``thoughtSummary`` for more details.
  public var text: String? {
    guard !candidates.isEmpty else {
      AILog.error(
        code: .generateContentResponseNoCandidates,
        "Could not get text from a response that had no candidates."
      )
      return nil
    }
    guard let value = text(isThought: false) else {
      AILog.error(
        code: .generateContentResponseNoText,
        "Could not get a text part from the first candidate."
      )
      return nil
    }
    return value
  }

  /// A summary of the model's thinking process, if available.
  ///
  /// - Important: Thought summaries are only available when `includeThoughts` is enabled in the
  ///   ``ThinkingConfig``. For more information, see the
  ///   [Thinking](https://firebase.google.com/docs/ai-logic/thinking) documentation.
  public var thoughtSummary: String? {
    guard candidates.first != nil else {
      AILog.error(
        code: .generateContentResponseNoCandidates,
        "Could not get text from a response that had no candidates."
      )
      return nil
    }
    guard let value = text(isThought: true) else {
      AILog.error(
        code: .generateContentResponseNoText,
        "Could not get a text part from any candidates."
      )
      return nil
    }
    return value
  }

  /// Returns function calls found in any `Part`s of the first candidate of the response, if any.
  public var functionCalls: [FunctionCallPart] {
    guard let candidate = candidates.first else {
      return []
    }
    return candidate.content.parts.compactMap { part in
      guard let functionCallPart = part as? FunctionCallPart, !part.isThought else {
        return nil
      }
      return functionCallPart
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
    return candidate.content.parts.compactMap { part in
      guard let inlineDataPart = part as? InlineDataPart, !part.isThought else {
        return nil
      }
      return inlineDataPart
    }
  }

  /// Initializer for SwiftUI previews or tests.
  public init(candidates: [Candidate], promptFeedback: PromptFeedback? = nil,
              usageMetadata: UsageMetadata? = nil) {
    self = .init(
      candidates: candidates,
      promptFeedback: promptFeedback,
      usageMetadata: usageMetadata,
      responseID: nil,
      modelVersion: nil
    )
  }

  init(candidates: [Candidate], promptFeedback: PromptFeedback? = nil,
       usageMetadata: UsageMetadata? = nil, responseID: String? = nil,
       modelVersion: String? = nil) {
    self.candidates = candidates
    self.promptFeedback = promptFeedback
    self.usageMetadata = usageMetadata
    self.responseID = responseID
    self.modelVersion = modelVersion ?? GenerateContentResponse.unknownModelVersion
  }

  func text(isThought: Bool) -> String? {
    guard let candidate = candidates.first else {
      return nil
    }
    let textValues: [String] = candidate.content.parts.compactMap { part in
      guard let textPart = part as? TextPart, part.isThought == isThought else {
        return nil
      }
      return textPart.text
    }
    guard textValues.count > 0 else {
      return nil
    }
    return textValues.joined(separator: " ")
  }
}

public enum CandidateKeys {
  public static let safetyRatings = "safetyRatings"
  public static let finishReason = "finishReason"
  public static let finishMessage = "finishMessage"
  public static let citationMetadata = "citationMetadata"
  public static let groundingMetadata = "groundingMetadata"
  public static let urlContextMetadata = "urlContextMetadata"
}

/// A struct representing a possible reply to a content generation prompt. Each content generation
/// prompt may produce multiple candidate responses.
public struct Candidate: Sendable {
  /// The response's content.
  public let content: ModelContent

  /// The safety rating of the response content.
  public let safetyRatings: [SafetyRating]

  /// The reason the model stopped generating content, if it exists; for example, if the model
  /// generated a predefined stop sequence.
  public let finishReason: FinishReason?

  /// A human-readable description of why the model stopped generating content, if it exists.
  public let finishMessage: String?

  /// Cited works in the model's response content, if it exists.
  public let citationMetadata: CitationMetadata?

  public let groundingMetadata: GroundingMetadata?

  /// Metadata related to the ``Tool/urlContext()`` tool.
  public let urlContextMetadata: URLContextMetadata?

  /// Initializer for SwiftUI previews or tests.
  public init(content: ModelContent, safetyRatings: [SafetyRating], finishReason: FinishReason?,
              citationMetadata: CitationMetadata?, groundingMetadata: GroundingMetadata? = nil,
              urlContextMetadata: URLContextMetadata? = nil, finishMessage: String? = nil) {
    self.content = content
    self.safetyRatings = safetyRatings
    self.finishReason = finishReason
    self.finishMessage = finishMessage
    self.citationMetadata = citationMetadata
    self.groundingMetadata = groundingMetadata
    self.urlContextMetadata = urlContextMetadata
  }

  // Returns `true` if the candidate contains no information that a developer could use.
  var isEmpty: Bool {
    content.parts
      .isEmpty && finishReason == nil && finishMessage == nil && citationMetadata == nil &&
      groundingMetadata == nil &&
      urlContextMetadata == nil
  }
}

/// A collection of source attributions for a piece of content.
public struct CitationMetadata: Sendable, Hashable {
  /// A list of individual cited sources and the parts of the content to which they apply.
  public let citations: [Citation]
}

/// A struct describing a source attribution.
public struct Citation: Sendable, Hashable {
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
public struct FinishReason: ProtoEnum, Hashable, Sendable {
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
    case imageSafety = "IMAGE_SAFETY"
    case imageProhibitedContent = "IMAGE_PROHIBITED_CONTENT"
    case imageOther = "IMAGE_OTHER"
    case noImage = "NO_IMAGE"
    case imageRecitation = "IMAGE_RECITATION"
    case language = "LANGUAGE"
    case unexpectedToolCall = "UNEXPECTED_TOOL_CALL"
    case tooManyToolCalls = "TOO_MANY_TOOL_CALLS"
    case missingThoughtSignature = "MISSING_THOUGHT_SIGNATURE"
    case malformedResponse = "MALFORMED_RESPONSE"
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

  /// Token generation stopped because generated images contain safety violations.
  public static let imageSafety = FinishReason(kind: .imageSafety)

  /// Image generation stopped because generated images have other prohibited content.
  public static let imageProhibitedContent = FinishReason(kind: .imageProhibitedContent)

  /// Image generation stopped because of other miscellaneous issue.
  public static let imageOther = FinishReason(kind: .imageOther)

  /// The model was expected to generate an image, but none was generated.
  public static let noImage = FinishReason(kind: .noImage)

  /// Image generation stopped due to recitation.
  public static let imageRecitation = FinishReason(kind: .imageRecitation)

  /// The response candidate content was flagged for using an unsupported language.
  public static let language = FinishReason(kind: .language)

  /// Model generated a tool call but no tools were enabled in the request.
  public static let unexpectedToolCall = FinishReason(kind: .unexpectedToolCall)

  /// Model called too many tools consecutively, thus the system exited execution.
  public static let tooManyToolCalls = FinishReason(kind: .tooManyToolCalls)

  /// Request has at least one thought signature missing.
  public static let missingThoughtSignature = FinishReason(kind: .missingThoughtSignature)

  /// Finished due to malformed response.
  public static let malformedResponse = FinishReason(kind: .malformedResponse)

  /// Returns the raw string representation of the `FinishReason` value.
  ///
  /// > Note: This value directly corresponds to the values in the [REST
  /// > API](https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/GenerateContentResponse#FinishReason).
  public let rawValue: String

  static let unrecognizedValueMessageCode =
    AILog.MessageCode.generateContentResponseUnrecognizedFinishReason
}

/// A metadata struct containing any feedback the model had on the prompt it was provided.
public struct PromptFeedback: Sendable {
  /// A type describing possible reasons to block a prompt.
  public struct BlockReason: ProtoEnum, Hashable, Sendable {
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

/// Metadata returned to the client when grounding is enabled.
///
/// > Important: If using Grounding with Google Search, you are required to comply with the
/// "Grounding with Google Search" usage requirements for your chosen API provider:
/// [Gemini Developer API](https://ai.google.dev/gemini-api/terms#grounding-with-google-search)
/// or Vertex AI Gemini API (see [Service Terms](https://cloud.google.com/terms/service-terms)
/// section within the Service Specific Terms).
public struct GroundingMetadata: Sendable, Equatable, Hashable {
  /// A list of web search queries that the model performed to gather the grounding information.
  /// These can be used to allow users to explore the search results themselves.
  public let webSearchQueries: [String]
  /// A list of ``GroundingChunk`` structs. Each chunk represents a piece of retrieved content
  /// (e.g., from a web page) that the model used to ground its response.
  public let groundingChunks: [GroundingChunk]
  /// A list of ``GroundingSupport`` structs. Each object details how specific segments of the
  /// model's response are supported by the `groundingChunks`.
  public let groundingSupports: [GroundingSupport]
  /// Google Search entry point for web searches.
  /// This contains an HTML/CSS snippet that **must** be embedded in an app to display a Google
  /// Search entry point for follow-up web searches related to the model's "Grounded Response".
  public let searchEntryPoint: SearchEntryPoint?

  /// A struct representing the Google Search entry point.
  public struct SearchEntryPoint: Sendable, Equatable, Hashable {
    /// An HTML/CSS snippet that can be embedded in your app.
    ///
    /// To ensure proper rendering, it's recommended to display this content within a `WKWebView`.
    public let renderedContent: String
  }

  /// Represents a chunk of retrieved data that supports a claim in the model's response. This is
  /// part of the grounding information provided when grounding is enabled.
  public struct GroundingChunk: Sendable, Equatable, Hashable {
    /// Contains details if the grounding chunk is from a web source.
    public let web: WebGroundingChunk?
    /// Contains details if the grounding chunk is from a Google Maps source.
    public let maps: GoogleMapsGroundingChunk?
  }

  /// A grounding chunk sourced from the web.
  public struct WebGroundingChunk: Sendable, Equatable, Hashable {
    /// The URI of the retrieved web page.
    public let uri: String?
    /// The title of the retrieved web page.
    public let title: String?
    /// The domain of the original URI from which the content was retrieved.
    ///
    /// This field is only populated when using the Vertex AI Gemini API.
    public let domain: String?
  }

  /// Provides information about how a specific segment of the model's response is supported by the
  /// retrieved grounding chunks.
  public struct GroundingSupport: Sendable, Equatable, Hashable {
    /// Specifies the segment of the model's response content that this grounding support pertains
    /// to.
    public let segment: Segment

    /// A list of indices that refer to specific ``GroundingChunk`` structs within the
    /// ``GroundingMetadata/groundingChunks`` array. These referenced chunks are the sources that
    /// support the claim made in the associated `segment` of the response. For example, an array
    /// `[1, 3, 4]`
    /// means that `groundingChunks[1]`, `groundingChunks[3]`, `groundingChunks[4]` are the
    /// retrieved content supporting this part of the response.
    public let groundingChunkIndices: [Int]

    struct Internal {
      let segment: Segment?
      let groundingChunkIndices: [Int]

      func toPublic() -> GroundingSupport? {
        if segment == nil {
          return nil
        }
        return GroundingSupport(
          segment: segment!,
          groundingChunkIndices: groundingChunkIndices
        )
      }
    }
  }
}

/// Represents a specific segment within a ``ModelContent`` struct, often used to pinpoint the
/// exact location of text or data that grounding information refers to.
public struct Segment: Sendable, Equatable, Hashable {
  /// The zero-based index of the ``Part`` object within the `parts` array of its parent
  /// ``ModelContent`` object. This identifies which part of the content the segment belongs to.
  public let partIndex: Int
  /// The zero-based start index of the segment within the specified ``Part``, measured in UTF-8
  /// bytes. This offset is inclusive, starting from 0 at the beginning of the part's content.
  public let startIndex: Int
  /// The zero-based end index of the segment within the specified ``Part``, measured in UTF-8
  /// bytes. This offset is exclusive, meaning the character at this index is not included in the
  /// segment.
  public let endIndex: Int
  /// The text corresponding to the segment from the response.
  public let text: String
}

// MARK: - Mappings

extension FinishReason {
  func toGoogleAI() -> GoogleAI.Candidate.FinishReason {
    GoogleAI.Candidate.FinishReason(rawValue: rawValue) ?? .unrecognized(rawValue)
  }

  func toAgentPlatform() -> AgentPlatform.Candidate.FinishReason {
    AgentPlatform.Candidate.FinishReason(rawValue: rawValue) ?? .unrecognized(rawValue)
  }

  init(fromGoogleAI reason: GoogleAI.Candidate.FinishReason) {
    self.init(rawValue: reason.rawValue)
  }

  init(fromAgentPlatform reason: AgentPlatform.Candidate.FinishReason) {
    self.init(rawValue: reason.rawValue)
  }
}

extension PromptFeedback.BlockReason {
  func toGoogleAI() -> GoogleAI.PromptFeedback.BlockReason {
    GoogleAI.PromptFeedback.BlockReason(rawValue: rawValue) ?? .unrecognized(rawValue)
  }

  func toAgentPlatform() -> AgentPlatform.PromptFeedback.BlockReason {
    AgentPlatform.PromptFeedback.BlockReason(rawValue: rawValue) ?? .unrecognized(rawValue)
  }

  init(fromGoogleAI reason: GoogleAI.PromptFeedback.BlockReason) {
    self.init(rawValue: reason.rawValue)
  }

  init(fromAgentPlatform reason: AgentPlatform.PromptFeedback.BlockReason) {
    self.init(rawValue: reason.rawValue)
  }
}

extension Citation {
  func toGoogleAI() -> GoogleAI.CitationSource {
    GoogleAI.CitationSource(
      endIndex: endIndex,
      license: license,
      startIndex: startIndex,
      uri: uri
    )
  }

  func toAgentPlatform() -> AgentPlatform.Citation {
    AgentPlatform.Citation(
      endIndex: endIndex,
      license: license,
      publicationDate: publicationDate.map { AgentPlatform.GoogleTypeDate(day: $0.day, month: $0.month, year: $0.year) },
      startIndex: startIndex,
      title: title,
      uri: uri
    )
  }

  init(fromGoogleAI citation: GoogleAI.CitationSource) {
    self.startIndex = citation.startIndex ?? 0
    self.endIndex = citation.endIndex ?? startIndex
    self.uri = citation.uri
    self.title = nil
    self.license = citation.license
    self.publicationDate = nil
  }

  init(fromAgentPlatform citation: AgentPlatform.Citation) {
    self.startIndex = citation.startIndex ?? 0
    self.endIndex = citation.endIndex ?? startIndex
    self.uri = citation.uri
    self.title = citation.title
    self.license = citation.license
    self.publicationDate = citation.publicationDate.map {
      DateComponents(
        calendar: Calendar(identifier: .gregorian),
        year: $0.year,
        month: $0.month,
        day: $0.day
      )
    }
  }
}

extension CitationMetadata {
  func toGoogleAI() -> GoogleAI.CitationMetadata {
    GoogleAI.CitationMetadata(
      citationSources: citations.map { $0.toGoogleAI() }
    )
  }

  func toAgentPlatform() -> AgentPlatform.CitationMetadata {
    AgentPlatform.CitationMetadata(
      citations: citations.map { $0.toAgentPlatform() }
    )
  }

  init(fromGoogleAI metadata: GoogleAI.CitationMetadata) {
    self.citations = metadata.citationSources?.map { Citation(fromGoogleAI: $0) } ?? []
  }

  init(fromAgentPlatform metadata: AgentPlatform.CitationMetadata) {
    self.citations = metadata.citations?.map { Citation(fromAgentPlatform: $0) } ?? []
  }
}

extension PromptFeedback {
  package func toGoogleAI() -> GoogleAI.PromptFeedback {
    GoogleAI.PromptFeedback(
      blockReason: blockReason?.toGoogleAI(),
      safetyRatings: safetyRatings.map { $0.toGoogleAI() }
    )
  }

  package func toAgentPlatform() -> AgentPlatform.PromptFeedback {
    AgentPlatform.PromptFeedback(
      blockReason: blockReason?.toAgentPlatform(),
      safetyRatings: safetyRatings.map { $0.toAgentPlatform() }
    )
  }

  package init(fromGoogleAI feedback: GoogleAI.PromptFeedback) {
    self.blockReason = feedback.blockReason.map { BlockReason(fromGoogleAI: $0) }
    self.blockReasonMessage = nil
    self.safetyRatings = feedback.safetyRatings?.map { SafetyRating(fromGoogleAI: $0) } ?? []
  }

  package init(fromAgentPlatform feedback: AgentPlatform.PromptFeedback) {
    self.blockReason = feedback.blockReason.map { BlockReason(fromAgentPlatform: $0) }
    self.blockReasonMessage = nil
    self.safetyRatings = feedback.safetyRatings?.map { SafetyRating(fromAgentPlatform: $0) } ?? []
  }
}

extension Candidate {
  package func toGoogleAI() -> GoogleAI.Candidate {
    GoogleAI.Candidate(
      citationMetadata: citationMetadata?.toGoogleAI(),
      content: content.toGoogleAI(),
      finishMessage: finishMessage,
      finishReason: finishReason?.toGoogleAI(),
      groundingMetadata: groundingMetadata?.toGoogleAI(),
      safetyRatings: safetyRatings.map { $0.toGoogleAI() },
      urlContextMetadata: urlContextMetadata?.toGoogleAI()
    )
  }

  package func toAgentPlatform() -> AgentPlatform.Candidate {
    AgentPlatform.Candidate(
      citationMetadata: citationMetadata?.toAgentPlatform(),
      content: content.toAgentPlatform(),
      finishMessage: finishMessage,
      finishReason: finishReason?.toAgentPlatform(),
      groundingMetadata: groundingMetadata?.toAgentPlatform(),
      safetyRatings: safetyRatings.map { $0.toAgentPlatform() },
      urlContextMetadata: urlContextMetadata?.toAgentPlatform()
    )
  }

  package init(fromGoogleAI candidate: GoogleAI.Candidate) {
    self.content = candidate.content.map { ModelContent(fromGoogleAI: $0) } ?? ModelContent(parts: [])
    self.safetyRatings = candidate.safetyRatings?.map { SafetyRating(fromGoogleAI: $0) } ?? []
    self.finishReason = candidate.finishReason.map { FinishReason(fromGoogleAI: $0) }
    self.finishMessage = candidate.finishMessage
    self.citationMetadata = candidate.citationMetadata.map { CitationMetadata(fromGoogleAI: $0) }
    self.groundingMetadata = candidate.groundingMetadata.map { GroundingMetadata(fromGoogleAI: $0) }
    self.urlContextMetadata = candidate.urlContextMetadata.map { URLContextMetadata(fromGoogleAI: $0) }
  }

  package init(fromAgentPlatform candidate: AgentPlatform.Candidate) {
    self.content = candidate.content.map { ModelContent(fromAgentPlatform: $0) } ?? ModelContent(parts: [])
    self.safetyRatings = candidate.safetyRatings?.map { SafetyRating(fromAgentPlatform: $0) } ?? []
    self.finishReason = candidate.finishReason.map { FinishReason(fromAgentPlatform: $0) }
    self.finishMessage = candidate.finishMessage
    self.citationMetadata = candidate.citationMetadata.map { CitationMetadata(fromAgentPlatform: $0) }
    self.groundingMetadata = candidate.groundingMetadata.map { GroundingMetadata(fromAgentPlatform: $0) }
    self.urlContextMetadata = candidate.urlContextMetadata.map { URLContextMetadata(fromAgentPlatform: $0) }
  }
}

extension GenerateContentResponse.UsageMetadata {
  func toGoogleAI() -> GoogleAI.UsageMetadata {
    GoogleAI.UsageMetadata(
      cacheTokensDetails: cacheTokensDetails.map { $0.toGoogleAI() },
      cachedContentTokenCount: cachedContentTokenCount,
      candidatesTokenCount: candidatesTokenCount,
      candidatesTokensDetails: candidatesTokensDetails.map { $0.toGoogleAI() },
      promptTokenCount: promptTokenCount,
      promptTokensDetails: promptTokensDetails.map { $0.toGoogleAI() },
      thoughtsTokenCount: thoughtsTokenCount,
      toolUsePromptTokenCount: toolUsePromptTokenCount,
      toolUsePromptTokensDetails: toolUsePromptTokensDetails.map { $0.toGoogleAI() },
      totalTokenCount: totalTokenCount
    )
  }

  func toAgentPlatform() -> AgentPlatform.UsageMetadata {
    AgentPlatform.UsageMetadata(
      cacheTokensDetails: cacheTokensDetails.map { $0.toAgentPlatform() },
      cachedContentTokenCount: cachedContentTokenCount,
      candidatesTokenCount: candidatesTokenCount,
      candidatesTokensDetails: candidatesTokensDetails.map { $0.toAgentPlatform() },
      promptTokenCount: promptTokenCount,
      promptTokensDetails: promptTokensDetails.map { $0.toAgentPlatform() },
      thoughtsTokenCount: thoughtsTokenCount,
      toolUsePromptTokenCount: toolUsePromptTokenCount,
      toolUsePromptTokensDetails: toolUsePromptTokensDetails.map { $0.toAgentPlatform() },
      totalTokenCount: totalTokenCount
    )
  }

  init(fromGoogleAI metadata: GoogleAI.UsageMetadata) {
    self.promptTokenCount = metadata.promptTokenCount ?? 0
    self.cachedContentTokenCount = metadata.cachedContentTokenCount ?? 0
    self.candidatesTokenCount = metadata.candidatesTokenCount ?? 0
    self.toolUsePromptTokenCount = metadata.toolUsePromptTokenCount ?? 0
    self.thoughtsTokenCount = metadata.thoughtsTokenCount ?? 0
    self.totalTokenCount = metadata.totalTokenCount ?? 0
    self.promptTokensDetails = metadata.promptTokensDetails?.map { ModalityTokenCount(fromGoogleAI: $0) } ?? []
    self.cacheTokensDetails = metadata.cacheTokensDetails?.map { ModalityTokenCount(fromGoogleAI: $0) } ?? []
    self.candidatesTokensDetails = metadata.candidatesTokensDetails?.map { ModalityTokenCount(fromGoogleAI: $0) } ?? []
    self.toolUsePromptTokensDetails = metadata.toolUsePromptTokensDetails?.map { ModalityTokenCount(fromGoogleAI: $0) } ?? []
  }

  init(fromAgentPlatform metadata: AgentPlatform.UsageMetadata) {
    self.promptTokenCount = metadata.promptTokenCount ?? 0
    self.cachedContentTokenCount = metadata.cachedContentTokenCount ?? 0
    self.candidatesTokenCount = metadata.candidatesTokenCount ?? 0
    self.toolUsePromptTokenCount = metadata.toolUsePromptTokenCount ?? 0
    self.thoughtsTokenCount = metadata.thoughtsTokenCount ?? 0
    self.totalTokenCount = metadata.totalTokenCount ?? 0
    self.promptTokensDetails = metadata.promptTokensDetails?.map { ModalityTokenCount(fromAgentPlatform: $0) } ?? []
    self.cacheTokensDetails = metadata.cacheTokensDetails?.map { ModalityTokenCount(fromAgentPlatform: $0) } ?? []
    self.candidatesTokensDetails = metadata.candidatesTokensDetails?.map { ModalityTokenCount(fromAgentPlatform: $0) } ?? []
    self.toolUsePromptTokensDetails = metadata.toolUsePromptTokensDetails?.map { ModalityTokenCount(fromAgentPlatform: $0) } ?? []
  }
}

extension Segment {
  func toGoogleAI() -> GoogleAI.GoogleAiGenerativelanguageV1betaSegment {
    GoogleAI.GoogleAiGenerativelanguageV1betaSegment(
      endIndex: endIndex,
      partIndex: partIndex,
      startIndex: startIndex,
      text: text
    )
  }

  func toAgentPlatform() -> AgentPlatform.Segment {
    AgentPlatform.Segment(
      endIndex: endIndex,
      partIndex: partIndex,
      startIndex: startIndex,
      text: text
    )
  }

  init(fromGoogleAI segment: GoogleAI.GoogleAiGenerativelanguageV1betaSegment) {
    self.partIndex = segment.partIndex ?? 0
    self.startIndex = segment.startIndex ?? 0
    self.endIndex = segment.endIndex ?? 0
    self.text = segment.text ?? ""
  }

  init(fromAgentPlatform segment: AgentPlatform.Segment) {
    self.partIndex = segment.partIndex ?? 0
    self.startIndex = segment.startIndex ?? 0
    self.endIndex = segment.endIndex ?? 0
    self.text = segment.text ?? ""
  }
}

extension GroundingMetadata.SearchEntryPoint {
  func toGoogleAI() -> GoogleAI.SearchEntryPoint {
    GoogleAI.SearchEntryPoint(htmlContent: htmlContent)
  }

  func toAgentPlatform() -> AgentPlatform.SearchEntryPoint {
    AgentPlatform.SearchEntryPoint(htmlContent: htmlContent)
  }

  init(fromGoogleAI entry: GoogleAI.SearchEntryPoint) {
    self.htmlContent = entry.htmlContent ?? ""
  }

  init(fromAgentPlatform entry: AgentPlatform.SearchEntryPoint) {
    self.htmlContent = entry.htmlContent ?? ""
  }
}

extension GroundingMetadata.GroundingSupport {
  func toGoogleAI() -> GoogleAI.GoogleAiGenerativelanguageV1betaGroundingSupport {
    GoogleAI.GoogleAiGenerativelanguageV1betaGroundingSupport(
      groundingChunkIndices: groundingChunkIndices,
      segment: segment.toGoogleAI()
    )
  }

  func toAgentPlatform() -> AgentPlatform.GroundingSupport {
    AgentPlatform.GroundingSupport(
      groundingChunkIndices: groundingChunkIndices,
      segment: segment.toAgentPlatform()
    )
  }

  init(fromGoogleAI support: GoogleAI.GoogleAiGenerativelanguageV1betaGroundingSupport) {
    self.groundingChunkIndices = support.groundingChunkIndices ?? []
    self.segment = support.segment.map { Segment(fromGoogleAI: $0) } ?? Segment(partIndex: 0, startIndex: 0, endIndex: 0, text: "")
  }

  init(fromAgentPlatform support: AgentPlatform.GroundingSupport) {
    self.groundingChunkIndices = support.groundingChunkIndices ?? []
    self.segment = support.segment.map { Segment(fromAgentPlatform: $0) } ?? Segment(partIndex: 0, startIndex: 0, endIndex: 0, text: "")
  }
}

extension GroundingMetadata.GroundingChunk {
  func toGoogleAI() -> GoogleAI.GroundingChunk {
    switch self {
    case let .web(web):
      return GoogleAI.GroundingChunk(web: GoogleAI.Web(title: web.title, uri: web.url?.absoluteString))
    case let .maps(maps):
      return GoogleAI.GroundingChunk(maps: maps.toGoogleAI())
    }
  }

  func toAgentPlatform() -> AgentPlatform.GroundingChunk {
    switch self {
    case let .web(web):
      return AgentPlatform.GroundingChunk(web: AgentPlatform.Web(title: web.title, uri: web.url?.absoluteString))
    case let .maps(maps):
      return AgentPlatform.GroundingChunk(maps: maps.toAgentPlatform())
    }
  }

  init?(fromGoogleAI chunk: GoogleAI.GroundingChunk) {
    if let web = chunk.web {
      self = .web(GroundingMetadata.WebGroundingChunk(title: web.title ?? "", url: web.uri.flatMap { URL(string: $0) }))
    } else if let maps = chunk.maps {
      self = .maps(GoogleMapsGroundingChunk(fromGoogleAI: maps))
    } else {
      return nil
    }
  }

  init?(fromAgentPlatform chunk: AgentPlatform.GroundingChunk) {
    if let web = chunk.web {
      self = .web(GroundingMetadata.WebGroundingChunk(title: web.title ?? "", url: web.uri.flatMap { URL(string: $0) }))
    } else if let maps = chunk.maps {
      self = .maps(GoogleMapsGroundingChunk(fromAgentPlatform: maps))
    } else {
      return nil
    }
  }
}

extension GroundingMetadata {
  package func toGoogleAI() -> GoogleAI.GroundingMetadata {
    GoogleAI.GroundingMetadata(
      groundingChunks: groundingChunks.map { $0.toGoogleAI() },
      groundingSupports: groundingSupports.map { $0.toGoogleAI() },
      searchEntryPoint: searchEntryPoint?.toGoogleAI(),
      webSearchQueries: webSearchQueries
    )
  }

  package func toAgentPlatform() -> AgentPlatform.GroundingMetadata {
    AgentPlatform.GroundingMetadata(
      groundingChunks: groundingChunks.map { $0.toAgentPlatform() },
      groundingSupports: groundingSupports.map { $0.toAgentPlatform() },
      searchEntryPoint: searchEntryPoint?.toAgentPlatform(),
      webSearchQueries: webSearchQueries
    )
  }

  package init(fromGoogleAI metadata: GoogleAI.GroundingMetadata) {
    self.webSearchQueries = metadata.webSearchQueries ?? []
    self.groundingChunks = metadata.groundingChunks?.compactMap { GroundingChunk(fromGoogleAI: $0) } ?? []
    self.groundingSupports = metadata.groundingSupports?.map { GroundingSupport(fromGoogleAI: $0) } ?? []
    self.searchEntryPoint = metadata.searchEntryPoint.map { SearchEntryPoint(fromGoogleAI: $0) }
  }

  package init(fromAgentPlatform metadata: AgentPlatform.GroundingMetadata) {
    self.webSearchQueries = metadata.webSearchQueries ?? []
    self.groundingChunks = metadata.groundingChunks?.compactMap { GroundingChunk(fromAgentPlatform: $0) } ?? []
    self.groundingSupports = metadata.groundingSupports?.map { GroundingSupport(fromAgentPlatform: $0) } ?? []
    self.searchEntryPoint = metadata.searchEntryPoint.map { SearchEntryPoint(fromAgentPlatform: $0) }
  }
}

extension GenerateContentResponse {
  package func toGoogleAI() -> GoogleAI.GenerateContentResponse {
    GoogleAI.GenerateContentResponse(
      candidates: candidates.map { $0.toGoogleAI() },
      modelVersion: modelVersion,
      promptFeedback: promptFeedback?.toGoogleAI(),
      responseId: responseID,
      usageMetadata: usageMetadata?.toGoogleAI()
    )
  }

  package func toAgentPlatform() -> AgentPlatform.GenerateContentResponse {
    AgentPlatform.GenerateContentResponse(
      candidates: candidates.map { $0.toAgentPlatform() },
      modelVersion: modelVersion,
      promptFeedback: promptFeedback?.toAgentPlatform(),
      responseId: responseID,
      usageMetadata: usageMetadata?.toAgentPlatform()
    )
  }

  package init(fromGoogleAI response: GoogleAI.GenerateContentResponse) {
    self.candidates = response.candidates?.map { Candidate(fromGoogleAI: $0) } ?? []
    self.promptFeedback = response.promptFeedback.map { PromptFeedback(fromGoogleAI: $0) }
    self.usageMetadata = response.usageMetadata.map { UsageMetadata(fromGoogleAI: $0) }
    self.responseID = response.responseId
    self.modelVersion = response.modelVersion ?? GenerateContentResponse.unknownModelVersion
  }

  package init(fromAgentPlatform response: AgentPlatform.GenerateContentResponse) {
    self.candidates = response.candidates?.map { Candidate(fromAgentPlatform: $0) } ?? []
    self.promptFeedback = response.promptFeedback.map { PromptFeedback(fromAgentPlatform: $0) }
    self.usageMetadata = response.usageMetadata.map { UsageMetadata(fromAgentPlatform: $0) }
    self.responseID = response.responseId
    self.modelVersion = response.modelVersion ?? GenerateContentResponse.unknownModelVersion
  }
}
