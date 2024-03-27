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
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct GenerateContentResponse {
  /// A list of candidate response content, ordered from best to worst.
  public let candidates: [CandidateResponse]

  /// A value containing the safety ratings for the response, or, if the request was blocked, a
  /// reason for blocking the request.
  public let promptFeedback: PromptFeedback?

  /// The response's content as text, if it exists.
  public var text: String? {
    guard let candidate = candidates.first else {
      Logging.default.error("Could not get text from a response that had no candidates.")
      return nil
    }
    guard let text = candidate.content.parts.first?.text else {
      Logging.default.error("Could not get a text part from the first candidate.")
      return nil
    }
    return text
  }

  /// Initializer for SwiftUI previews or tests.
  public init(candidates: [CandidateResponse], promptFeedback: PromptFeedback?) {
    self.candidates = candidates
    self.promptFeedback = promptFeedback
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension GenerateContentResponse: Decodable {
  enum CodingKeys: CodingKey {
    case candidates
    case promptFeedback
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
      [CandidateResponse].self,
      forKey: .candidates
    ) {
      self.candidates = candidates
    } else {
      candidates = []
    }
    promptFeedback = try container.decodeIfPresent(PromptFeedback.self, forKey: .promptFeedback)
  }
}

/// A struct representing a possible reply to a content generation prompt. Each content generation
/// prompt may produce multiple candidate responses.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct CandidateResponse {
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

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CandidateResponse: Decodable {
  enum CodingKeys: CodingKey {
    case content
    case safetyRatings
    case finishReason
    case finishMessage
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
      // Check if `content` can be decoded as an empty dictionary to detect the `"content": {}` bug.
      if let content = try? container.decode([String: String].self, forKey: .content),
         content.isEmpty {
        throw InvalidCandidateError.emptyContent(underlyingError: error)
      } else {
        throw InvalidCandidateError.malformedContent(underlyingError: error)
      }
    }

    if let safetyRatings = try container.decodeIfPresent(
      [SafetyRating].self,
      forKey: .safetyRatings
    ) {
      self.safetyRatings = safetyRatings
    } else {
      safetyRatings = []
    }

    finishReason = try container.decodeIfPresent(FinishReason.self, forKey: .finishReason)

    citationMetadata = try container.decodeIfPresent(
      CitationMetadata.self,
      forKey: .citationMetadata
    )
  }
}

/// A collection of source attributions for a piece of content.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct CitationMetadata: Decodable {
  enum CodingKeys: String, CodingKey {
    case citationSources = "citations"
  }

  /// A list of individual cited sources and the parts of the content to which they apply.
  public let citationSources: [Citation]
}

/// A struct describing a source attribution.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct Citation: Decodable {
  /// The inclusive beginning of a sequence in a model response that derives from a cited source.
  public let startIndex: Int

  /// The exclusive end of a sequence in a model response that derives from a cited source.
  public let endIndex: Int

  /// A link to the cited source.
  public let uri: String

  /// The license the cited source work is distributed under.
  public let license: String?
}

/// A value enumerating possible reasons for a model to terminate a content generation request.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public enum FinishReason: String {
  case unknown = "FINISH_REASON_UNKNOWN"

  case unspecified = "FINISH_REASON_UNSPECIFIED"

  /// Natural stop point of the model or provided stop sequence.
  case stop = "STOP"

  /// The maximum number of tokens as specified in the request was reached.
  case maxTokens = "MAX_TOKENS"

  /// The token generation was stopped because the response was flagged for safety reasons.
  /// NOTE: When streaming, the Candidate.content will be empty if content filters blocked the
  /// output.
  case safety = "SAFETY"

  /// The token generation was stopped because the response was flagged for unauthorized citations.
  case recitation = "RECITATION"

  /// All other reasons that stopped token generation.
  case other = "OTHER"
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension FinishReason: Decodable {
  /// Do not explicitly use. Initializer required for Decodable conformance.
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let decodedFinishReason = FinishReason(rawValue: value) else {
      Logging.default
        .error("[GoogleGenerativeAI] Unrecognized FinishReason with value \"\(value)\".")
      self = .unknown
      return
    }

    self = decodedFinishReason
  }
}

/// A metadata struct containing any feedback the model had on the prompt it was provided.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct PromptFeedback {
  /// A type describing possible reasons to block a prompt.
  public enum BlockReason: String, Decodable {
    /// The block reason is unknown.
    case unknown = "UNKNOWN"

    /// The block reason was not specified in the server response.
    case unspecified = "BLOCK_REASON_UNSPECIFIED"

    /// The prompt was blocked because it was deemed unsafe.
    case safety = "SAFETY"

    /// All other block reasons.
    case other = "OTHER"

    /// Do not explicitly use. Initializer required for Decodable conformance.
    public init(from decoder: Decoder) throws {
      let value = try decoder.singleValueContainer().decode(String.self)
      guard let decodedBlockReason = BlockReason(rawValue: value) else {
        Logging.default
          .error("[GoogleGenerativeAI] Unrecognized BlockReason with value \"\(value)\".")
        self = .unknown
        return
      }

      self = decodedBlockReason
    }
  }

  /// The reason a prompt was blocked, if it was blocked.
  public let blockReason: BlockReason?

  /// The safety ratings of the prompt.
  public let safetyRatings: [SafetyRating]

  /// Initializer for SwiftUI previews or tests.
  public init(blockReason: BlockReason?, safetyRatings: [SafetyRating]) {
    self.blockReason = blockReason
    self.safetyRatings = safetyRatings
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension PromptFeedback: Decodable {
  enum CodingKeys: CodingKey {
    case blockReason
    case safetyRatings
  }

  /// Do not explicitly use. Initializer required for Decodable conformance.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    blockReason = try container.decodeIfPresent(
      PromptFeedback.BlockReason.self,
      forKey: .blockReason
    )
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
