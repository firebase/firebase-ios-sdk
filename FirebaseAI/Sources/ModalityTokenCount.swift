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
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ModalityTokenCount: Sendable {
  /// The modality associated with this token count.
  public let modality: ContentModality

  /// The number of tokens counted.
  public let tokenCount: Int
}

/// Content part modality.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ContentModality: DecodableProtoEnum, Hashable, Sendable {
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

// MARK: Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModalityTokenCount: Decodable {
  enum CodingKeys: CodingKey {
    case modality
    case tokenCount
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    modality = try container.decode(ContentModality.self, forKey: .modality)
    tokenCount = try container.decodeIfPresent(Int.self, forKey: .tokenCount) ?? 0
  }
}
