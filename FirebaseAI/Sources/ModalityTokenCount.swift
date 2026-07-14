// Copyright 2025 Google LLC
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

/// Represents token counting info for a single modality.
public struct ModalityTokenCount: Sendable {
  /// The modality associated with this token count.
  public let modality: ContentModality

  /// The number of tokens counted.
  public let tokenCount: Int
}

/// Content part modality.
public struct ContentModality: ProtoEnum, Hashable, Sendable {
  enum Kind: String {
    case text = "TEXT"
    case image = "IMAGE"
    case video = "VIDEO"
    case audio = "AUDIO"
    case document = "DOCUMENT"
  }

  /// Plain text.
  public static let text = ContentModality(kind: .text)

  /// Image.
  public static let image = ContentModality(kind: .image)

  /// Video.
  public static let video = ContentModality(kind: .video)

  /// Audio.
  public static let audio = ContentModality(kind: .audio)

  /// Document, e.g. PDF.
  public static let document = ContentModality(kind: .document)

  /// Returns the raw string representation of the `ContentModality` value.
  public let rawValue: String

  static let unrecognizedValueMessageCode =
    AILog.MessageCode.generateContentResponseUnrecognizedContentModality
}

// MARK: - Mappings

import GoogleAIDataModels
import AgentPlatformDataModels

extension ContentModality {
  func toGoogleAI() -> GoogleAI.ModalityTokenCount.Modality {
    GoogleAI.ModalityTokenCount.Modality(rawValue: rawValue)
  }

  func toAgentPlatform() -> AgentPlatform.ModalityTokenCount.Modality {
    AgentPlatform.ModalityTokenCount.Modality(rawValue: rawValue)
  }

  init(fromGoogleAI modality: GoogleAI.ModalityTokenCount.Modality) {
    self.init(rawValue: modality.rawValue)
  }

  init(fromAgentPlatform modality: AgentPlatform.ModalityTokenCount.Modality) {
    self.init(rawValue: modality.rawValue)
  }
}

extension ModalityTokenCount {
  package func toGoogleAI() -> GoogleAI.ModalityTokenCount {
    GoogleAI.ModalityTokenCount(
      modality: modality.toGoogleAI(),
      tokenCount: tokenCount
    )
  }

  package func toAgentPlatform() -> AgentPlatform.ModalityTokenCount {
    AgentPlatform.ModalityTokenCount(
      modality: modality.toAgentPlatform(),
      tokenCount: tokenCount
    )
  }

  package init(fromGoogleAI count: GoogleAI.ModalityTokenCount) {
    self.modality = count.modality.map { ContentModality(fromGoogleAI: $0) } ?? .text
    self.tokenCount = count.tokenCount ?? 0
  }

  package init(fromAgentPlatform count: AgentPlatform.ModalityTokenCount) {
    self.modality = count.modality.map { ContentModality(fromAgentPlatform: $0) } ?? .text
    self.tokenCount = count.tokenCount ?? 0
  }
}
