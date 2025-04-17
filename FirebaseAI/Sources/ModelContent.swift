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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension [ModelContent] {
  // TODO: Rename and refactor this.
  func throwIfError() throws {
    for content in self {
      for part in content.parts {
        switch part {
        case let errorPart as ErrorPart:
          throw errorPart.error
        default:
          break
        }
      }
    }
  }
}

/// A type describing data in media formats interpretable by an AI model. Each generative AI
/// request or response contains an `Array` of ``ModelContent``s, and each ``ModelContent`` value
/// may comprise multiple heterogeneous ``Part``s.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ModelContent: Equatable, Sendable {
  enum InternalPart: Equatable, Sendable {
    case text(String)
    case inlineData(mimetype: String, Data)
    case fileData(mimetype: String, uri: String)
    case functionCall(FunctionCall)
    case functionResponse(FunctionResponse)
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
        convertedParts.append(InlineDataPart(data: data, mimeType: mimetype))
      case let .fileData(mimetype, uri):
        convertedParts.append(FileDataPart(uri: uri, mimeType: mimetype))
      case let .functionCall(functionCall):
        convertedParts.append(FunctionCallPart(functionCall))
      case let .functionResponse(functionResponse):
        convertedParts.append(FunctionResponsePart(functionResponse))
      }
    }
    return convertedParts
  }

  // TODO: Refactor this
  let internalParts: [InternalPart]

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
        convertedParts.append(.fileData(mimetype: fileData.mimeType, uri: fileData.fileURI))
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
  public init(role: String? = "user", parts: any PartsRepresentable...) {
    let content = parts.flatMap { $0.partsValue }
    self.init(role: role, parts: content)
  }
}

// MARK: Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModelContent: Codable {
  enum CodingKeys: String, CodingKey {
    case role
    case internalParts = "parts"
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModelContent.InternalPart: Codable {
  enum CodingKeys: String, CodingKey {
    case text
    case inlineData
    case fileData
    case functionCall
    case functionResponse
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .text(text):
      try container.encode(text, forKey: .text)
    case let .inlineData(mimetype, bytes):
      try container.encode(InlineData(data: bytes, mimeType: mimetype), forKey: .inlineData)
    case let .fileData(mimetype: mimetype, url):
      try container.encode(FileData(fileURI: url, mimeType: mimetype), forKey: .fileData)
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
      let inlineData = try values.decode(InlineData.self, forKey: .inlineData)
      self = .inlineData(mimetype: inlineData.mimeType, inlineData.data)
    } else if values.contains(.fileData) {
      let fileData = try values.decode(FileData.self, forKey: .fileData)
      self = .fileData(mimetype: fileData.mimeType, uri: fileData.fileURI)
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
