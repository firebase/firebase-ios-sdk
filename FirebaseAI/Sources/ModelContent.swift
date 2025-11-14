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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct InternalPart: Equatable, Sendable {
  enum OneOfData: Equatable, Sendable {
    case text(String)
    case inlineData(InlineData)
    case fileData(FileData)
    case functionCall(FunctionCall)
    case functionResponse(FunctionResponse)
    case executableCode(ExecutableCode)
    case codeExecutionResult(CodeExecutionResult)

    struct UnsupportedDataError: Error {
      let decodingError: DecodingError

      var localizedDescription: String {
        decodingError.localizedDescription
      }
    }
  }

  let data: OneOfData?

  let isThought: Bool?

  let thoughtSignature: String?

  init(_ data: OneOfData, isThought: Bool?, thoughtSignature: String?) {
    self.data = data
    self.isThought = isThought
    self.thoughtSignature = thoughtSignature
  }
}

/// A type describing data in media formats interpretable by an AI model. Each generative AI
/// request or response contains an `Array` of ``ModelContent``s, and each ``ModelContent`` value
/// may comprise multiple heterogeneous ``Part``s.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ModelContent: Equatable, Sendable {
  /// The role of the entity creating the ``ModelContent``. For user-generated client requests,
  /// for example, the role is `user`.
  public let role: String?

  /// The data parts comprising this ``ModelContent`` value.
  public var parts: [any Part] {
    return internalParts.compactMap { part -> (any Part)? in
      switch part.data {
      case let .text(text):
        return TextPart(text, isThought: part.isThought, thoughtSignature: part.thoughtSignature)
      case let .inlineData(inlineData):
        return InlineDataPart(
          inlineData, isThought: part.isThought, thoughtSignature: part.thoughtSignature
        )
      case let .fileData(fileData):
        return FileDataPart(
          fileData, isThought: part.isThought, thoughtSignature: part.thoughtSignature
        )
      case let .functionCall(functionCall):
        return FunctionCallPart(
          functionCall, isThought: part.isThought, thoughtSignature: part.thoughtSignature
        )
      case let .functionResponse(functionResponse):
        return FunctionResponsePart(
          functionResponse, isThought: part.isThought, thoughtSignature: part.thoughtSignature
        )
      case let .executableCode(executableCode):
        return ExecutableCodePart(
          executableCode, isThought: part.isThought, thoughtSignature: part.thoughtSignature
        )
      case let .codeExecutionResult(codeExecutionResult):
        return CodeExecutionResultPart(
          codeExecutionResult: codeExecutionResult,
          isThought: part.isThought,
          thoughtSignature: part.thoughtSignature
        )
      case .none:
        // Filter out parts that contain missing or unrecognized data
        return nil
      }
    }
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
        convertedParts.append(InternalPart(
          .text(textPart.text),
          isThought: textPart._isThought,
          thoughtSignature: textPart.thoughtSignature
        ))
      case let inlineDataPart as InlineDataPart:
        convertedParts.append(InternalPart(
          .inlineData(inlineDataPart.inlineData),
          isThought: inlineDataPart._isThought,
          thoughtSignature: inlineDataPart.thoughtSignature
        ))
      case let fileDataPart as FileDataPart:
        convertedParts.append(InternalPart(
          .fileData(fileDataPart.fileData),
          isThought: fileDataPart._isThought,
          thoughtSignature: fileDataPart.thoughtSignature
        ))
      case let functionCallPart as FunctionCallPart:
        convertedParts.append(InternalPart(
          .functionCall(functionCallPart.functionCall),
          isThought: functionCallPart._isThought,
          thoughtSignature: functionCallPart.thoughtSignature
        ))
      case let functionResponsePart as FunctionResponsePart:
        convertedParts.append(InternalPart(
          .functionResponse(functionResponsePart.functionResponse),
          isThought: functionResponsePart._isThought,
          thoughtSignature: functionResponsePart.thoughtSignature
        ))
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

  init(role: String?, parts: [InternalPart]) {
    self.role = role
    internalParts = parts
  }
}

// MARK: Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ModelContent: Codable {
  enum CodingKeys: String, CodingKey {
    case role
    case internalParts = "parts"
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    role = try container.decodeIfPresent(String.self, forKey: .role)
    internalParts = try container.decodeIfPresent([InternalPart].self, forKey: .internalParts) ?? []
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension InternalPart: Codable {
  enum CodingKeys: String, CodingKey {
    case isThought = "thought"
    case thoughtSignature
  }

  public func encode(to encoder: Encoder) throws {
    try data.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(isThought, forKey: .isThought)
    try container.encodeIfPresent(thoughtSignature, forKey: .thoughtSignature)
  }

  public init(from decoder: Decoder) throws {
    do {
      data = try OneOfData(from: decoder)
    } catch let error as OneOfData.UnsupportedDataError {
      AILog.error(code: .decodedUnsupportedPartData, error.localizedDescription)
      data = nil
    } catch { // Re-throw any other error types
      throw error
    }
    let container = try decoder.container(keyedBy: CodingKeys.self)
    isThought = try container.decodeIfPresent(Bool.self, forKey: .isThought)
    thoughtSignature = try container.decodeIfPresent(String.self, forKey: .thoughtSignature)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension InternalPart.OneOfData: Codable {
  enum CodingKeys: String, CodingKey {
    case text
    case inlineData
    case fileData
    case functionCall
    case functionResponse
    case executableCode
    case codeExecutionResult
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case let .text(text):
      try container.encode(text, forKey: .text)
    case let .inlineData(inlineData):
      try container.encode(inlineData, forKey: .inlineData)
    case let .fileData(fileData):
      try container.encode(fileData, forKey: .fileData)
    case let .functionCall(functionCall):
      try container.encode(functionCall, forKey: .functionCall)
    case let .functionResponse(functionResponse):
      try container.encode(functionResponse, forKey: .functionResponse)
    case let .executableCode(executableCode):
      try container.encode(executableCode, forKey: .executableCode)
    case let .codeExecutionResult(codeExecutionResult):
      try container.encode(codeExecutionResult, forKey: .codeExecutionResult)
    }
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    if values.contains(.text) {
      self = try .text(values.decode(String.self, forKey: .text))
    } else if values.contains(.inlineData) {
      self = try .inlineData(values.decode(InlineData.self, forKey: .inlineData))
    } else if values.contains(.fileData) {
      self = try .fileData(values.decode(FileData.self, forKey: .fileData))
    } else if values.contains(.functionCall) {
      self = try .functionCall(values.decode(FunctionCall.self, forKey: .functionCall))
    } else if values.contains(.functionResponse) {
      self = try .functionResponse(values.decode(FunctionResponse.self, forKey: .functionResponse))
    } else if values.contains(.executableCode) {
      self = try .executableCode(values.decode(ExecutableCode.self, forKey: .executableCode))
    } else if values.contains(.codeExecutionResult) {
      self = try .codeExecutionResult(
        values.decode(CodeExecutionResult.self, forKey: .codeExecutionResult)
      )
    } else {
      let unexpectedKeys = values.allKeys.map { $0.stringValue }
      throw UnsupportedDataError(decodingError: DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: values.codingPath,
          debugDescription: "Unexpected Part type(s): \(unexpectedKeys)"
        )
      ))
    }
  }
}
