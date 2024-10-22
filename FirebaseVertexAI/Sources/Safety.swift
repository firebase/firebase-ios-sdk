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
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct SafetyRating: Equatable, Hashable, Sendable {
  /// The category describing the potential harm a piece of content may pose.
  ///
  /// See ``HarmCategory`` for a list of possible values.
  public let category: HarmCategory

  /// The model-generated probability that the content falls under the specified harm ``category``.
  ///
  /// See ``HarmProbability`` for a list of possible values. This is a discretized representation
  /// of the ``probabilityScore``.
  ///
  /// > Important: This does not indicate the severity of harm for a piece of content.
  public let probability: HarmProbability

  /// The confidence score that the response is associated with the corresponding harm ``category``.
  ///
  /// The probability safety score is a confidence score between 0.0 and 1.0, rounded to one decimal
  /// place; it is discretized into a ``HarmProbability`` in ``probability``. See [probability
  /// scores](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/configure-safety-filters#comparison_of_probability_scores_and_severity_scores)
  /// in the Google Cloud documentation for more details.
  public let probabilityScore: Float

  /// The severity reflects the magnitude of how harmful a model response might be.
  ///
  /// See ``HarmSeverity`` for a list of possible values. This is a discretized representation of
  /// the ``severityScore``.
  public let severity: HarmSeverity

  /// The severity score is the magnitude of how harmful a model response might be.
  ///
  /// The severity score ranges from 0.0 to 1.0, rounded to one decimal place; it is discretized
  /// into a ``HarmSeverity`` in ``severity``. See [severity scores](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/configure-safety-filters#comparison_of_probability_scores_and_severity_scores)
  /// in the Google Cloud documentation for more details.
  public let severityScore: Float

  /// If true, the response was blocked.
  public let blocked: Bool

  /// Initializes a new `SafetyRating` instance with the given category and probability.
  /// Use this initializer for SwiftUI previews or tests.
  public init(category: HarmCategory,
              probability: HarmProbability,
              probabilityScore: Float,
              severity: HarmSeverity,
              severityScore: Float,
              blocked: Bool) {
    self.category = category
    self.probability = probability
    self.probabilityScore = probabilityScore
    self.severity = severity
    self.severityScore = severityScore
    self.blocked = blocked
  }

  /// The probability that a given model output falls under a harmful content category.
  ///
  /// > Note: This does not indicate the severity of harm for a piece of content.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  public struct HarmProbability: DecodableProtoEnum, Hashable, Sendable {
    enum Kind: String {
      case negligible = "NEGLIGIBLE"
      case low = "LOW"
      case medium = "MEDIUM"
      case high = "HIGH"
    }

    /// The probability is zero or close to zero.
    ///
    /// For benign content, the probability across all categories will be this value.
    public static let negligible = HarmProbability(kind: .negligible)

    /// The probability is small but non-zero.
    public static let low = HarmProbability(kind: .low)

    /// The probability is moderate.
    public static let medium = HarmProbability(kind: .medium)

    /// The probability is high.
    ///
    /// The content described is very likely harmful.
    public static let high = HarmProbability(kind: .high)

    /// Returns the raw string representation of the `HarmProbability` value.
    ///
    /// > Note: This value directly corresponds to the values in the [REST
    /// > API](https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/GenerateContentResponse#SafetyRating).
    public let rawValue: String

    static let unrecognizedValueMessageCode =
      VertexLog.MessageCode.generateContentResponseUnrecognizedHarmProbability
  }

  /// The magnitude of how harmful a model response might be for the respective ``HarmCategory``.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  public struct HarmSeverity: DecodableProtoEnum, Hashable, Sendable {
    enum Kind: String {
      case negligible = "HARM_SEVERITY_NEGLIGIBLE"
      case low = "HARM_SEVERITY_LOW"
      case medium = "HARM_SEVERITY_MEDIUM"
      case high = "HARM_SEVERITY_HIGH"
    }

    /// Negligible level of harm severity.
    public static let negligible = HarmSeverity(kind: .negligible)

    /// Low level of harm severity.
    public static let low = HarmSeverity(kind: .low)

    /// Medium level of harm severity.
    public static let medium = HarmSeverity(kind: .medium)

    /// High level of harm severity.
    public static let high = HarmSeverity(kind: .high)

    /// Returns the raw string representation of the `HarmSeverity` value.
    ///
    /// > Note: This value directly corresponds to the values in the [REST
    /// > API](https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/GenerateContentResponse#HarmSeverity).
    public let rawValue: String

    static let unrecognizedValueMessageCode =
      VertexLog.MessageCode.generateContentResponseUnrecognizedHarmSeverity
  }
}

/// A type used to specify a threshold for harmful content, beyond which the model will return a
/// fallback response instead of generated content.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct SafetySetting {
  /// Block at and beyond a specified ``SafetyRating/HarmProbability``.
  public struct HarmBlockThreshold: EncodableProtoEnum, Sendable {
    enum Kind: String {
      case blockLowAndAbove = "BLOCK_LOW_AND_ABOVE"
      case blockMediumAndAbove = "BLOCK_MEDIUM_AND_ABOVE"
      case blockOnlyHigh = "BLOCK_ONLY_HIGH"
      case blockNone = "BLOCK_NONE"
      case off = "OFF"
    }

    /// Content with `.negligible` will be allowed.
    public static let blockLowAndAbove = HarmBlockThreshold(kind: .blockLowAndAbove)

    /// Content with `.negligible` and `.low` will be allowed.
    public static let blockMediumAndAbove = HarmBlockThreshold(kind: .blockMediumAndAbove)

    /// Content with `.negligible`, `.low`, and `.medium` will be allowed.
    public static let blockOnlyHigh = HarmBlockThreshold(kind: .blockOnlyHigh)

    /// All content will be allowed.
    public static let blockNone = HarmBlockThreshold(kind: .blockNone)

    /// Turn off the safety filter.
    public static let off = HarmBlockThreshold(kind: .off)

    let rawValue: String
  }

  /// The method of computing whether the ``SafetySetting/HarmBlockThreshold`` has been exceeded.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  public struct HarmBlockMethod: EncodableProtoEnum, Sendable {
    enum Kind: String {
      case severity = "SEVERITY"
      case probability = "PROBABILITY"
    }

    /// Use both probability and severity scores.
    public static let severity = HarmBlockMethod(kind: .severity)

    /// Use only the probability score.
    public static let probability = HarmBlockMethod(kind: .probability)

    let rawValue: String
  }

  enum CodingKeys: String, CodingKey {
    case harmCategory = "category"
    case threshold
    case method
  }

  /// The category this safety setting should be applied to.
  public let harmCategory: HarmCategory

  /// The threshold describing what content should be blocked.
  public let threshold: HarmBlockThreshold

  /// The method of computing whether the ``threshold`` has been exceeded.
  public let method: HarmBlockMethod?

  /// Initializes a new safety setting with the given category and threshold.
  ///
  /// - Parameters:
  ///   - harmCategory: The category this safety setting should be applied to.
  ///   - threshold: The threshold describing what content should be blocked.
  ///   - method: The method of computing whether the threshold has been exceeded; if not specified,
  ///     the default method is ``HarmBlockMethod/severity`` for most models. See [harm block
  ///     methods](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/configure-safety-filters#how_to_configure_safety_filters)
  ///     in the Google Cloud documentation for more details.
  ///     > Note: For models older than `gemini-1.5-flash` and `gemini-1.5-pro`, the default method
  ///     > is ``HarmBlockMethod/probability``.
  public init(harmCategory: HarmCategory, threshold: HarmBlockThreshold,
              method: HarmBlockMethod? = nil) {
    self.harmCategory = harmCategory
    self.threshold = threshold
    self.method = method
  }
}

/// Categories describing the potential harm a piece of content may pose.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct HarmCategory: CodableProtoEnum, Hashable, Sendable {
  enum Kind: String {
    case harassment = "HARM_CATEGORY_HARASSMENT"
    case hateSpeech = "HARM_CATEGORY_HATE_SPEECH"
    case sexuallyExplicit = "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    case dangerousContent = "HARM_CATEGORY_DANGEROUS_CONTENT"
    case civicIntegrity = "HARM_CATEGORY_CIVIC_INTEGRITY"
  }

  /// Harassment content.
  public static let harassment = HarmCategory(kind: .harassment)

  /// Negative or harmful comments targeting identity and/or protected attributes.
  public static let hateSpeech = HarmCategory(kind: .hateSpeech)

  /// Contains references to sexual acts or other lewd content.
  public static let sexuallyExplicit = HarmCategory(kind: .sexuallyExplicit)

  /// Promotes or enables access to harmful goods, services, or activities.
  public static let dangerousContent = HarmCategory(kind: .dangerousContent)

  /// Content that may be used to harm civic integrity.
  public static let civicIntegrity = HarmCategory(kind: .civicIntegrity)

  /// Returns the raw string representation of the `HarmCategory` value.
  ///
  /// > Note: This value directly corresponds to the values in the
  /// > [REST API](https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/HarmCategory).
  public let rawValue: String

  static let unrecognizedValueMessageCode =
    VertexLog.MessageCode.generateContentResponseUnrecognizedHarmCategory
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension SafetyRating: Decodable {
  enum CodingKeys: CodingKey {
    case category
    case probability
    case probabilityScore
    case severity
    case severityScore
    case blocked
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    category = try container.decode(HarmCategory.self, forKey: .category)
    probability = try container.decode(HarmProbability.self, forKey: .probability)

    // The following 3 fields are only omitted in our test data.
    probabilityScore = try container.decodeIfPresent(Float.self, forKey: .probabilityScore) ?? 0.0
    severity = try container.decodeIfPresent(HarmSeverity.self, forKey: .severity) ??
      HarmSeverity(rawValue: "HARM_SEVERITY_UNSPECIFIED")
    severityScore = try container.decodeIfPresent(Float.self, forKey: .severityScore) ?? 0.0

    // The blocked field is only included when true.
    blocked = try container.decodeIfPresent(Bool.self, forKey: .blocked) ?? false
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension SafetySetting.HarmBlockThreshold: Encodable {}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension SafetySetting: Encodable {}
