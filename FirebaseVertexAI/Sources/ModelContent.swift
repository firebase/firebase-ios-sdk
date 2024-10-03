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

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension [ModelContent] {
  // TODO: Rename and refactor this.
  func throwIfError() throws {
    for content in self {
      for part in content.parts {
        switch part {
        case let errorPart as ErrorPart:
          throw errorPart
        default:
          break
        }
      }
    }
  }
}

/// A type describing data in media formats interpretable by an AI model. Each generative AI
/// request or response contains an `Array` of ``ModelContent``s, and each ``ModelContent`` value
/// may comprise multiple heterogeneous ``ModelContent/Part``s.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ModelContent: Equatable, Sendable {
  /// A discrete piece of data in a media format interpretable by an AI model. Within a single value
  /// of ``Part``, different data types may not mix.
  enum InternalPart: Equatable, Sendable {
    /// Text value.
    case text(String)

    /// Data with a specified media type. Not all media types may be supported by the AI model.
    case inlineData(mimetype: String, Data)

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
      return .inlineData(mimetype: "image/jpeg", data)
    }

    /// Convenience function for populating a Part with PNG data.
    public static func png(_ data: Data) -> Self {
      return .inlineData(mimetype: "image/png", data)
    }
  }

  /// The role of the entity creating the ``ModelContent``. For user-generated client requests,
  /// for example, the role is `user`.
  public let role: String?

  /// The data parts comprising this ``ModelContent`` value.
  public var parts: [any Part] {
    var convertedParts = [any Part]()
    for part in internalParts {
      switch part {
      case let .text(text):
        convertedParts.append(TextPart(text))
      case let .inlineData(mimetype, data):
        convertedParts
          .append(InlineDataPart(inlineData: InlineData(mimeType: mimetype, data: data)))
      case let .fileData(mimetype, uri):
        convertedParts.append(FileDataPart(fileData: FileData(mimeType: mimetype, uri: uri)))
      case let .functionCall(functionCall):
        convertedParts.append(FunctionCallPart(functionCall: functionCall))
      case let .functionResponse(functionResponse):
        convertedParts.append(FunctionResponsePart(functionResponse: functionResponse))
      }
    }
    return convertedParts
  }

  // TODO: Refactor this
  let internalParts: [InternalPart]

  /// Creates a new value from any data or `Array` of data interpretable as a
  /// ``Part``. See ``PartsRepresentable`` for types that can be interpreted as `Part`s.
  public init(role: String? = "user", parts: some PartsRepresentable) {
    self.role = role
    var convertedParts = [InternalPart]()
    for part in parts.partsValue {
      switch part {
      case let textPart as TextPart:
        convertedParts.append(.text(textPart.text))
      case let inlineDataPart as InlineDataPart:
        let inlineData = inlineDataPart.inlineData
        convertedParts.append(.inlineData(mimetype: inlineData.mimeType, inlineData.data))
      case let fileDataPart as FileDataPart:
        let fileData = fileDataPart.fileData
        convertedParts.append(.fileData(mimetype: fileData.mimeType, uri: fileData.uri))
      case let functionCallPart as FunctionCallPart:
        convertedParts.append(.functionCall(functionCallPart.functionCall))
      case let functionResponsePart as FunctionResponsePart:
        convertedParts.append(.functionResponse(functionResponsePart.functionResponse))
      default:
        fatalError()
      }
    }
    internalParts = convertedParts
  }

  /// Creates a new value from a list of ``Part``s.
  public init(role: String? = "user", parts: [any Part]) {
    self.role = role
    var convertedParts = [InternalPart]()
    for part in parts {
      switch part {
      case let textPart as TextPart:
        convertedParts.append(.text(textPart.text))
      case let inlineDataPart as InlineDataPart:
        let inlineData = inlineDataPart.inlineData
        convertedParts.append(.inlineData(mimetype: inlineData.mimeType, inlineData.data))
      case let fileDataPart as FileDataPart:
        let fileData = fileDataPart.fileData
        convertedParts.append(.fileData(mimetype: fileData.mimeType, uri: fileData.uri))
      case let functionCallPart as FunctionCallPart:
        convertedParts.append(.functionCall(functionCallPart.functionCall))
      case let functionResponsePart as FunctionResponsePart:
        convertedParts.append(.functionResponse(functionResponsePart.functionResponse))
      default:
        fatalError()
      }
    }
    internalParts = convertedParts
  }

  /// Creates a new value from any data interpretable as a ``Part``.
  /// See ``PartsRepresentable`` for types that can be interpreted as `Part`s.
  public init(role: String? = "user", _ parts: any PartsRepresentable...) {
    let content = parts.flatMap { $0.partsValue }
    self.init(role: role, parts: content)
  }

  /// Creates a new value from any data interpretable as a ``Part``.
  /// See ``PartsRepresentable``for types that can be interpreted as `Part`s.
  public init(role: String? = "user", _ parts: [PartsRepresentable]) {
    let content = parts.flatMap { $0.partsValue }
    self.init(role: role, parts: content)
  }
}

// MARK: Codable Conformances

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModelContent: Codable {
  enum CodingKeys: String, CodingKey {
    case role
    case internalParts = "parts"
  }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModelContent.InternalPart: Codable {
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

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .text(a0):
      try container.encode(a0, forKey: .text)
    case let .inlineData(mimetype, bytes):
      var inlineDataContainer = container.nestedContainer(
        keyedBy: InlineDataKeys.self,
        forKey: .inlineData
      )
      try inlineDataContainer.encode(mimetype, forKey: .mimeType)
      try inlineDataContainer.encode(bytes, forKey: .bytes)
    case let .fileData(mimetype: mimetype, url):
//      var fileDataContainer = container.nestedContainer(
//        keyedBy: FileDataKeys.self,
//        forKey: .fileData
//      )
      try container.encode(FileData(mimeType: mimetype, uri: url), forKey: .fileData)
//      try fileDataContainer.encode(mimetype, forKey: .mimeType)
//      try fileDataContainer.encode(url, forKey: .uri)
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
      self = .inlineData(mimetype: mimetype, bytes)
    } else if values.contains(.functionCall) {
      self = try .functionCall(values.decode(FunctionCall.self, forKey: .functionCall))
    } else if values.contains(.functionResponse) {
      self = try .functionResponse(values.decode(FunctionResponse.self, forKey: .functionResponse))
    } else {
      let unexpectedKeys = values.allKeys.map { $0.stringValue }
      throw DecodingError.dataCorrupted(DecodingError.Context(
        codingPath: values.codingPath,
        debugDescription: "Unexpected Part type(s): \(unexpectedKeys)"
      ))
    }
  }
}
