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

/// An internal data model for `HarmCategory`.
package enum HarmCategory: Codable, Sendable, Equatable, Hashable {

  /// Content that promotes violence or incites hatred against individuals or
  /// groups based on certain attributes.
  case hateSpeech

  /// Content that promotes, facilitates, or enables dangerous activities.
  case dangerousContent

  /// Abusive, threatening, or content intended to bully, torment, or ridicule.
  case harassment

  /// Content that contains sexually explicit material.
  case sexuallyExplicit

  /// Deprecated: Election filter is not longer supported.
  /// The harm category is civic integrity.
  case civicIntegrity

  /// Images that contain hate speech.
  case imageHate

  /// Images that contain dangerous content.
  case imageDangerousContent

  /// Images that contain harassment.
  case imageHarassment

  /// Images that contain sexually explicit content.
  case imageSexuallyExplicit

  /// Prompts designed to bypass safety filters.
  case jailbreak

  /// Unrecognized case.
  ///
  /// - Parameter value: The raw string value of the unrecognized enum case.
  case unrecognized(_ value: String)
}

// MARK: - RawRepresentable Conformance

extension HarmCategory: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .hateSpeech: "hate_speech"
    case .dangerousContent: "dangerous_content"
    case .harassment: "harassment"
    case .sexuallyExplicit: "sexually_explicit"
    case .civicIntegrity: "civic_integrity"
    case .imageHate: "image_hate"
    case .imageDangerousContent: "image_dangerous_content"
    case .imageHarassment: "image_harassment"
    case .imageSexuallyExplicit: "image_sexually_explicit"
    case .jailbreak: "jailbreak"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "hate_speech": self = .hateSpeech
    case "dangerous_content": self = .dangerousContent
    case "harassment": self = .harassment
    case "sexually_explicit": self = .sexuallyExplicit
    case "civic_integrity": self = .civicIntegrity
    case "image_hate": self = .imageHate
    case "image_dangerous_content": self = .imageDangerousContent
    case "image_harassment": self = .imageHarassment
    case "image_sexually_explicit": self = .imageSexuallyExplicit
    case "jailbreak": self = .jailbreak
    default: self = .unrecognized(rawValue)
    }
  }
}
