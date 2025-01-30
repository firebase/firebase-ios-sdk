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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ModalityTokenCount: Sendable {
  let modality: Modality
  let tokenCount: Int
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct Modality: CodableProtoEnum, Hashable, Sendable {
  enum Kind: String {
    case unspecified = "MODALITY_UNSPECIFIED"
    case text = "TEXT"
    case image = "IMAGE"
    case video = "VIDEO"
    case audio = "AUDIO"
    case document = "DOCUMENT"
  }

  /// Harassment content.
  public static let unspecified = Modality(kind: .unspecified)

  /// Negative or harmful comments targeting identity and/or protected attributes.
  public static let text = Modality(kind: .text)

  /// Contains references to sexual acts or other lewd content.
  public static let image = Modality(kind: .image)

  /// Promotes or enables access to harmful goods, services, or activities.
  public static let video = Modality(kind: .video)

  /// Content that may be used to harm civic integrity.
  public static let audio = Modality(kind: .audio)

  /// Content that may be used to harm civic integrity.
  public static let document = Modality(kind: .document)

  /// Returns the raw string representation of the `HarmCategory` value.
  ///
  /// > Note: This value directly corresponds to the values in the
  /// > [REST API](https://cloud.google.com/vertex-ai/docs/reference/rest/v1beta1/HarmCategory).
  public let rawValue: String

  static let unrecognizedValueMessageCode =
    VertexLog.MessageCode.generateContentResponseUnrecognizedHarmCategory
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModalityTokenCount: Decodable {}
