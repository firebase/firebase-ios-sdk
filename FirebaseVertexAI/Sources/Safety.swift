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

/// A type defining potentially harmful media categories and their model-assigned ratings. A value
/// of this type may be assigned to a category for every model-generated response, not just
/// responses that exceed a certain threshold.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct SafetyRating: Equatable, Hashable {
  /// The category describing the potential harm a piece of content may pose. See
  /// ``SafetySetting/HarmCategory`` for a list of possible values.
  public let category: SafetySetting.HarmCategory

  /// The model-generated probability that a given piece of content falls under the harm category
  /// described in ``category``. This does not
  /// indiciate the severity of harm for a piece of content. See ``HarmProbability`` for a list of
  /// possible values.
  public let probability: HarmProbability

  /// Initializes a new `SafetyRating` instance with the given category and probability.
  /// Use this initializer for SwiftUI previews or tests.
  public init(category: SafetySetting.HarmCategory, probability: HarmProbability) {
    self.category = category
    self.probability = probability
  }

  /// The probability that a given model output falls under a harmful content category. This does
  /// not indicate the severity of harm for a piece of content.
  public enum HarmProbability: String {
    /// Unknown. A new server value that isn't recognized by the SDK.
    case unknown = "UNKNOWN"

    /// The probability was not specified in the server response.
    case unspecified = "HARM_PROBABILITY_UNSPECIFIED"

    /// The probability is zero or close to zero. For benign content, the probability across all
    /// categories will be this value.
    case negligible = "NEGLIGIBLE"

    /// The probability is small but non-zero.
    case low = "LOW"

    /// The probability is moderate.
    case medium = "MEDIUM"

    /// The probability is high. The content described is very likely harmful.
    case high = "HIGH"
  }
}

/// Safety feedback for an entire request.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct SafetyFeedback {
  /// Safety rating evaluated from content.
  public let rating: SafetyRating

  /// Safety settings applied to the request.
  public let setting: SafetySetting

  /// Internal initializer.
  init(rating: SafetyRating, setting: SafetySetting) {
    self.rating = rating
    self.setting = setting
  }
}

/// A type used to specify a threshold for harmful content, beyond which the model will return a
/// fallback response instead of generated content.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct SafetySetting {
  /// A type describing safety attributes, which include harmful categories and topics that can
  /// be considered sensitive.
  public enum HarmCategory: String {
    /// Unknown. A new server value that isn't recognized by the SDK.
    case unknown = "HARM_CATEGORY_UNKNOWN"

    /// Unspecified by the server.
    case unspecified = "HARM_CATEGORY_UNSPECIFIED"

    /// Harassment content.
    case harassment = "HARM_CATEGORY_HARASSMENT"

    /// Negative or harmful comments targeting identity and/or protected attributes.
    case hateSpeech = "HARM_CATEGORY_HATE_SPEECH"

    /// Contains references to sexual acts or other lewd content.
    case sexuallyExplicit = "HARM_CATEGORY_SEXUALLY_EXPLICIT"

    /// Promotes or enables access to harmful goods, services, or activities.
    case dangerousContent = "HARM_CATEGORY_DANGEROUS_CONTENT"
  }

  /// Block at and beyond a specified ``SafetyRating/HarmProbability``.
  public enum BlockThreshold: String {
    /// Unknown. A new server value that isn't recognized by the SDK.
    case unknown = "UNKNOWN"

    /// Threshold is unspecified.
    case unspecified = "HARM_BLOCK_THRESHOLD_UNSPECIFIED"

    // Content with `.negligible` will be allowed.
    case blockLowAndAbove = "BLOCK_LOW_AND_ABOVE"

    /// Content with `.negligible` and `.low` will be allowed.
    case blockMediumAndAbove = "BLOCK_MEDIUM_AND_ABOVE"

    /// Content with `.negligible`, `.low`, and `.medium` will be allowed.
    case blockOnlyHigh = "BLOCK_ONLY_HIGH"

    /// All content will be allowed.
    case blockNone = "BLOCK_NONE"
  }

  enum CodingKeys: String, CodingKey {
    case harmCategory = "category"
    case threshold
  }

  /// The category this safety setting should be applied to.
  public let harmCategory: HarmCategory

  /// The threshold describing what content should be blocked.
  public let threshold: BlockThreshold

  /// Initializes a new safety setting with the given category and threshold.
  public init(harmCategory: HarmCategory, threshold: BlockThreshold) {
    self.harmCategory = harmCategory
    self.threshold = threshold
  }
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension SafetyRating.HarmProbability: Codable {
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let decodedProbability = SafetyRating.HarmProbability(rawValue: value) else {
      Logging.default
        .error("[GoogleGenerativeAI] Unrecognized HarmProbability with value \"\(value)\".")
      self = .unknown
      return
    }

    self = decodedProbability
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension SafetyRating: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension SafetyFeedback: Decodable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension SafetySetting.HarmCategory: Codable {
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let decodedCategory = SafetySetting.HarmCategory(rawValue: value) else {
      Logging.default
        .error("[GoogleGenerativeAI] Unrecognized HarmCategory with value \"\(value)\".")
      self = .unknown
      return
    }

    self = decodedCategory
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension SafetySetting.BlockThreshold: Codable {
  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let decodedThreshold = SafetySetting.BlockThreshold(rawValue: value) else {
      Logging.default
        .error("[GoogleGenerativeAI] Unrecognized BlockThreshold with value \"\(value)\".")
      self = .unknown
      return
    }

    self = decodedThreshold
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension SafetySetting: Codable {}
