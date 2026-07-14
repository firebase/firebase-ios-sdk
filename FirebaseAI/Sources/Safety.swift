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

/// A type defining potentially harmful media categories and their model-assigned ratings. A value
/// of this type may be assigned to a category for every model-generated response, not just
/// responses that exceed a certain threshold.
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
  public struct HarmProbability: ProtoEnum, Hashable, Sendable {
    enum Kind: String {
      case unspecified = "HARM_PROBABILITY_UNSPECIFIED"
      case negligible = "NEGLIGIBLE"
      case low = "LOW"
      case medium = "MEDIUM"
      case high = "HIGH"
    }

    /// Internal-only; harm probability is unknown or unspecified by the backend.
    static let unspecified = HarmProbability(kind: .unspecified)

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
      AILog.MessageCode.generateContentResponseUnrecognizedHarmProbability
  }

  /// The magnitude of how harmful a model response might be for the respective ``HarmCategory``.
  public struct HarmSeverity: ProtoEnum, Hashable, Sendable {
    enum Kind: String {
      case unspecified = "HARM_SEVERITY_UNSPECIFIED"
      case negligible = "HARM_SEVERITY_NEGLIGIBLE"
      case low = "HARM_SEVERITY_LOW"
      case medium = "HARM_SEVERITY_MEDIUM"
      case high = "HARM_SEVERITY_HIGH"
    }

    /// Internal-only; harm severity is unknown or unspecified by the backend.
    static let unspecified: HarmSeverity = .init(kind: .unspecified)

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
      AILog.MessageCode.generateContentResponseUnrecognizedHarmSeverity
  }
}

/// A type used to specify a threshold for harmful content, beyond which the model will return a
/// fallback response instead of generated content.
///
/// See [safety settings for Gemini
/// models](https://firebase.google.com/docs/vertex-ai/safety-settings?platform=ios#gemini) for
/// more details.
public struct SafetySetting: Sendable, Hashable {
  /// Block at and beyond a specified ``SafetyRating/HarmProbability``.
  public struct HarmBlockThreshold: ProtoEnum, Sendable, Hashable {
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
  public struct HarmBlockMethod: ProtoEnum, Sendable, Hashable {
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
public struct HarmCategory: ProtoEnum, Hashable, Sendable {
  enum Kind: String {
    case unspecified = "HARM_CATEGORY_UNSPECIFIED"
    case harassment = "HARM_CATEGORY_HARASSMENT"
    case hateSpeech = "HARM_CATEGORY_HATE_SPEECH"
    case sexuallyExplicit = "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    case dangerousContent = "HARM_CATEGORY_DANGEROUS_CONTENT"
    case civicIntegrity = "HARM_CATEGORY_CIVIC_INTEGRITY"
  }

  /// Internal-only; harm category is unknown or unspecified by the backend.
  static let unspecified = HarmCategory(kind: .unspecified)

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
    AILog.MessageCode.generateContentResponseUnrecognizedHarmCategory
}

// MARK: - Mappings

extension HarmCategory {
  func toGoogleAI() -> GoogleAI.SafetySetting.Category {
    GoogleAI.SafetySetting.Category(rawValue: rawValue)
  }

  func toAgentPlatform() -> AgentPlatform.SafetySetting.Category {
    AgentPlatform.SafetySetting.Category(rawValue: rawValue)
  }

  init(fromGoogleAI category: GoogleAI.SafetySetting.Category) {
    self.init(rawValue: category.rawValue)
  }

  init(fromAgentPlatform category: AgentPlatform.SafetySetting.Category) {
    self.init(rawValue: category.rawValue)
  }

  init(fromGoogleAI category: GoogleAI.SafetyRating.Category) {
    self.init(rawValue: category.rawValue)
  }

  init(fromAgentPlatform category: AgentPlatform.SafetyRating.Category) {
    self.init(rawValue: category.rawValue)
  }
}

extension SafetySetting.HarmBlockThreshold {
  func toGoogleAI() -> GoogleAI.SafetySetting.Threshold {
    GoogleAI.SafetySetting.Threshold(rawValue: rawValue)
  }

  func toAgentPlatform() -> AgentPlatform.SafetySetting.Threshold {
    AgentPlatform.SafetySetting.Threshold(rawValue: rawValue)
  }

  init(fromGoogleAI threshold: GoogleAI.SafetySetting.Threshold) {
    self.init(rawValue: threshold.rawValue)
  }

  init(fromAgentPlatform threshold: AgentPlatform.SafetySetting.Threshold) {
    self.init(rawValue: threshold.rawValue)
  }
}

extension SafetySetting.HarmBlockMethod {
  func toGoogleAI() -> String {
    rawValue
  }

  func toAgentPlatform() -> AgentPlatform.SafetySetting.Method {
    AgentPlatform.SafetySetting.Method(rawValue: rawValue)
  }

  init?(fromAgentPlatform method: AgentPlatform.SafetySetting.Method) {
    self.init(rawValue: method.rawValue)
  }
}

extension SafetySetting {
  package func toGoogleAI() -> GoogleAI.SafetySetting {
    GoogleAI.SafetySetting(
      category: harmCategory.toGoogleAI(),
      threshold: threshold.toGoogleAI()
    )
  }

  package func toAgentPlatform() -> AgentPlatform.SafetySetting {
    AgentPlatform.SafetySetting(
      category: harmCategory.toAgentPlatform(),
      method: method?.toAgentPlatform(),
      threshold: threshold.toAgentPlatform()
    )
  }

  package init(fromGoogleAI setting: GoogleAI.SafetySetting) {
    self.harmCategory = HarmCategory(fromGoogleAI: setting.category ?? .unspecified)
    self.threshold = SafetySetting.HarmBlockThreshold(fromGoogleAI: setting.threshold ?? .blockNone)
    self.method = nil
  }

  package init(fromAgentPlatform setting: AgentPlatform.SafetySetting) {
    self.harmCategory = HarmCategory(fromAgentPlatform: setting.category ?? .unspecified)
    self.threshold = SafetySetting.HarmBlockThreshold(fromAgentPlatform: setting.threshold ?? .blockNone)
    self.method = setting.method.flatMap { HarmBlockMethod(fromAgentPlatform: $0) }
  }
}

extension HarmProbability {
  func toGoogleAI() -> GoogleAI.SafetyRating.Probability {
    GoogleAI.SafetyRating.Probability(rawValue: rawValue)
  }

  func toAgentPlatform() -> AgentPlatform.SafetyRating.Probability {
    AgentPlatform.SafetyRating.Probability(rawValue: rawValue)
  }

  init(fromGoogleAI prob: GoogleAI.SafetyRating.Probability) {
    self.init(rawValue: prob.rawValue)
  }

  init(fromAgentPlatform prob: AgentPlatform.SafetyRating.Probability) {
    self.init(rawValue: prob.rawValue)
  }
}

extension HarmSeverity {
  func toGoogleAI() -> GoogleAI.SafetyRating.Severity? {
    nil
  }

  func toAgentPlatform() -> AgentPlatform.SafetyRating.Severity {
    AgentPlatform.SafetyRating.Severity(rawValue: rawValue)
  }

  init(fromAgentPlatform sev: AgentPlatform.SafetyRating.Severity) {
    self.init(rawValue: sev.rawValue)
  }
}

extension SafetyRating {
  package init(fromGoogleAI rating: GoogleAI.SafetyRating) {
    self.category = HarmCategory(fromGoogleAI: rating.category ?? .unspecified)
    self.probability = HarmProbability(fromGoogleAI: rating.probability ?? .unspecified)
    self.probabilityScore = 0.0
    self.severity = .unspecified
    self.severityScore = 0.0
    self.blocked = rating.blocked ?? false
  }

  package init(fromAgentPlatform rating: AgentPlatform.SafetyRating) {
    self.category = HarmCategory(fromAgentPlatform: rating.category ?? .unspecified)
    self.probability = HarmProbability(fromAgentPlatform: rating.probability ?? .unspecified)
    self.probabilityScore = Float(rating.probabilityScore ?? 0.0)
    self.severity = rating.severity.map { HarmSeverity(fromAgentPlatform: $0) } ?? .unspecified
    self.severityScore = Float(rating.severityScore ?? 0.0)
    self.blocked = rating.blocked ?? false
  }

  package func toGoogleAI() -> GoogleAI.SafetyRating {
    GoogleAI.SafetyRating(
      blocked: blocked,
      category: category.toGoogleAI(),
      probability: probability.toGoogleAI()
    )
  }

  package func toAgentPlatform() -> AgentPlatform.SafetyRating {
    AgentPlatform.SafetyRating(
      blocked: blocked,
      category: category.toAgentPlatform(),
      probability: probability.toAgentPlatform(),
      probabilityScore: Double(probabilityScore),
      severity: severity.toAgentPlatform(),
      severityScore: Double(severityScore)
    )
  }
}
