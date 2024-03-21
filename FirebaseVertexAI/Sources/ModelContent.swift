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

/// A type describing data in media formats interpretable by an AI model. Each generative AI
/// request or response contains an `Array` of ``ModelContent``s, and each ``ModelContent`` value
/// may comprise multiple heterogeneous ``ModelContent/Part``s.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public struct ModelContent: Codable, Equatable {
  /// A discrete piece of data in a media format intepretable by an AI model. Within a single value
  /// of ``Part``, different data types may not mix.
  public enum Part: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
      case text
      case inlineData
      case fileData
    }

    enum InlineDataKeys: String, CodingKey {
      case mimeType = "mime_type"
      case bytes = "data"
    }

    enum FileDataKeys: String, CodingKey {
      case mimeType = "mime_type"
      case url = "file_uri"
    }

    /// Text value.
    case text(String)

    /// Data with a specified media type. Not all media types may be supported by the AI model.
    case data(mimetype: String, Data)

    /// URI based data with a specified media type. Not all media types may be supported by the AI
    /// model.
    case fileData(mimetype: String, URL)

    // MARK: Convenience Initializers

    /// Convenience function for populating a Part with JPEG data.
    public static func jpeg(_ data: Data) -> Self {
      return .data(mimetype: "image/jpeg", data)
    }

    /// Convenience function for populating a Part with PNG data.
    public static func png(_ data: Data) -> Self {
      return .data(mimetype: "image/png", data)
    }

    // MARK: Codable Conformance

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: ModelContent.Part.CodingKeys.self)
      switch self {
      case let .text(a0):
        try container.encode(a0, forKey: .text)
      case let .data(mimetype, bytes):
        var inlineDataContainer = container.nestedContainer(
          keyedBy: InlineDataKeys.self,
          forKey: .inlineData
        )
        try inlineDataContainer.encode(mimetype, forKey: .mimeType)
        try inlineDataContainer.encode(bytes, forKey: .bytes)
      case let .fileData(mimetype: mimetype, url):
        var fileDataContainer = container.nestedContainer(
          keyedBy: FileDataKeys.self,
          forKey: .fileData
        )
        try fileDataContainer.encode(mimetype, forKey: .mimeType)
        try fileDataContainer.encode(url, forKey: .url)
      }
    }

    public init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      if values.contains(.text) {
        self = try .text(values.decode(String.self, forKey: .text))
      } else if values.contains(.inlineData) {
        let dataContainer = try values.nestedContainer(
          keyedBy: InlineDataKeys.self,
          forKey: .inlineData
        )
        let mimetype = try dataContainer.decode(String.self, forKey: .mimeType)
        let bytes = try dataContainer.decode(Data.self, forKey: .bytes)
        self = .data(mimetype: mimetype, bytes)
      } else {
        throw DecodingError.dataCorrupted(.init(
          codingPath: [CodingKeys.text, CodingKeys.inlineData],
          debugDescription: "Neither text or inline data was found."
        ))
      }
    }

    /// Returns the text contents of this ``Part``, if it contains text.
    public var text: String? {
      switch self {
      case let .text(contents): return contents
      default: return nil
      }
    }
  }

  /// The role of the entity creating the ``ModelContent``. For user-generated client requests,
  /// for example, the role is `user`.
  public let role: String?

  /// The data parts comprising this ``ModelContent`` value.
  public let parts: [Part]

  /// Creates a new value from any data or `Array` of data interpretable as a
  /// ``Part``. See ``ThrowingPartsRepresentable`` for types that can be interpreted as `Part`s.
  public init(role: String? = "user", parts: some ThrowingPartsRepresentable) throws {
    self.role = role
    try self.parts = parts.tryPartsValue()
  }

  /// Creates a new value from any data or `Array` of data interpretable as a
  /// ``Part``. See ``ThrowingPartsRepresentable`` for types that can be interpreted as `Part`s.
  public init(role: String? = "user", parts: some PartsRepresentable) {
    self.role = role
    self.parts = parts.partsValue
  }

  /// Creates a new value from a list of ``Part``s.
  public init(role: String? = "user", parts: [Part]) {
    self.role = role
    self.parts = parts
  }

  /// Creates a new value from any data interpretable as a ``Part``. See
  /// ``ThrowingPartsRepresentable``
  /// for types that can be interpreted as `Part`s.
  public init(role: String? = "user", _ parts: any ThrowingPartsRepresentable...) throws {
    let content = try parts.flatMap { try $0.tryPartsValue() }
    self.init(role: role, parts: content)
  }

  /// Creates a new value from any data interpretable as a ``Part``. See
  /// ``ThrowingPartsRepresentable``
  /// for types that can be interpreted as `Part`s.
  public init(role: String? = "user", _ parts: [PartsRepresentable]) {
    let content = parts.flatMap { $0.partsValue }
    self.init(role: role, parts: content)
  }
}
