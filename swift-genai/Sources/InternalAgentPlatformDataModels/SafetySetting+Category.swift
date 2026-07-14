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

import Foundation

extension AgentPlatform.SafetySetting {
  /// Required. The harm category to be blocked.
  public enum Category: Codable, Sendable, Equatable, Hashable {
    /// Content that promotes violence or incites hatred against individuals or groups based on certain attributes.
    case hateSpeech
    
    /// Content that promotes, facilitates, or enables dangerous activities.
    case dangerousContent
    
    /// Abusive, threatening, or content intended to bully, torment, or ridicule.
    case harassment
    
    /// Content that contains sexually explicit material.
    case sexuallyExplicit
    
    /// Deprecated: Election filter is not longer supported. The harm category is civic integrity.
    @available(*, deprecated)
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
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.SafetySetting.Category: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .hateSpeech: "HARM_CATEGORY_HATE_SPEECH"
    case .dangerousContent: "HARM_CATEGORY_DANGEROUS_CONTENT"
    case .harassment: "HARM_CATEGORY_HARASSMENT"
    case .sexuallyExplicit: "HARM_CATEGORY_SEXUALLY_EXPLICIT"
    case .civicIntegrity: "HARM_CATEGORY_CIVIC_INTEGRITY"
    case .imageHate: "HARM_CATEGORY_IMAGE_HATE"
    case .imageDangerousContent: "HARM_CATEGORY_IMAGE_DANGEROUS_CONTENT"
    case .imageHarassment: "HARM_CATEGORY_IMAGE_HARASSMENT"
    case .imageSexuallyExplicit: "HARM_CATEGORY_IMAGE_SEXUALLY_EXPLICIT"
    case .jailbreak: "HARM_CATEGORY_JAILBREAK"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "HARM_CATEGORY_HATE_SPEECH": self = .hateSpeech
    case "HARM_CATEGORY_DANGEROUS_CONTENT": self = .dangerousContent
    case "HARM_CATEGORY_HARASSMENT": self = .harassment
    case "HARM_CATEGORY_SEXUALLY_EXPLICIT": self = .sexuallyExplicit
    case "HARM_CATEGORY_CIVIC_INTEGRITY": self = .civicIntegrity
    case "HARM_CATEGORY_IMAGE_HATE": self = .imageHate
    case "HARM_CATEGORY_IMAGE_DANGEROUS_CONTENT": self = .imageDangerousContent
    case "HARM_CATEGORY_IMAGE_HARASSMENT": self = .imageHarassment
    case "HARM_CATEGORY_IMAGE_SEXUALLY_EXPLICIT": self = .imageSexuallyExplicit
    case "HARM_CATEGORY_JAILBREAK": self = .jailbreak
    default: self = .unrecognized(rawValue)
    }
  }
}