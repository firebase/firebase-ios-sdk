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
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ModelContent: Equatable {
  /// A discrete piece of data in a media format interpretable by an AI model. Within a single value
  /// of ``Part``, different data types may not mix.
  public enum Part: Equatable {
    /// Text value.
    case text(String)

    /// Data with a specified media type. Not all media types may be supported by the AI model.
    case data(mimetype: String, Data)

    /// File data stored in Cloud Storage for Firebase, referenced by URI.
    ///
    /// > Note: Supported media types depends on the model; see [media requirements
    /// > ](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/send-multimodal-prompts#media_requirements)
    /// > for details.
    ///
    /// - Parameters:
    ///   - mimetype: The IANA standard MIME type of the uploaded file, for example, `"image/jpeg"`
    ///     or `"video/mp4"`; see [media requirements
    ///     ](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/send-multimodal-prompts#media_requirements)
    ///     for supported values.
    ///   - uri: The `"gs://"`-prefixed URI of the file in Cloud Storage for Firebase, for example,
    ///     `"gs://bucket-name/path/image.jpg"`.
    case fileData(mimetype: String, uri: String)

    /// A predicted function call returned from the model.
    case functionCall(FunctionCall)

    /// A response to a function call.
    case functionResponse(FunctionResponse)

    // MARK: Convenience Initializers

    /// Convenience function for populating a Part with JPEG data.
    public static func jpeg(_ data: Data) -> Self {
      return .data(mimetype: "image/jpeg", data)
    }

    /// Convenience function for populating a Part with PNG data.
    public static func png(_ data: Data) -> Self {
      return .data(mimetype: "image/png", data)
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

// MARK: Codable Conformances

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModelContent: Codable {}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModelContent.Part: Codable {
  enum CodingKeys: String, CodingKey {
    case text
    case inlineData
    case fileData
    case functionCall
    case functionResponse
  }

  enum InlineDataKeys: String, CodingKey {
    case mimeType = "mime_type"
    case bytes = "data"
  }

  enum FileDataKeys: String, CodingKey {
    case mimeType = "mime_type"
    case uri = "file_uri"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
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
      try fileDataContainer.encode(url, forKey: .uri)
    case let .functionCall(functionCall):
      try container.encode(functionCall, forKey: .functionCall)
    case let .functionResponse(functionResponse):
      try container.encode(functionResponse, forKey: .functionResponse)
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
    } else if values.contains(.functionCall) {
      self = try .functionCall(values.decode(FunctionCall.self, forKey: .functionCall))
    } else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: [CodingKeys.text, CodingKeys.inlineData],
        debugDescription: "No text, inline data or function call was found."
      ))
    }
  }
}
