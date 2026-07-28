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
internal import InternalGoogleGenAI

extension [ModelContent] {
  // TODO: Rename and refactor this.
  func throwIfError() throws {
    for content in self {
      if let errorPart = content.errorParts.first {
        throw errorPart.error
      }
    }
  }
}

/// A type describing data in media formats interpretable by an AI model. Each generative AI
/// request or response contains an `Array` of ``ModelContent``s, and each ``ModelContent`` value
/// may comprise multiple heterogeneous ``Part``s.
public struct ModelContent: Equatable, Sendable {
  let internalContent: GenerateContentAPI.Content
  let errorParts: [ErrorPart]

  /// The role of the entity creating the ``ModelContent``. For user-generated client requests,
  /// for example, the role is `user`.
  public var role: String? {
    internalContent.role
  }

  /// The data parts comprising this ``ModelContent`` value.
  public var parts: [any Part] {
    let payloadParts = internalContent.parts ?? []
    var convertedParts: [any Part] = payloadParts.compactMap { payloadPart -> (any Part)? in
      let isThought = payloadPart.thought

      guard let data = payloadPart.data else {
        return nil
      }

      switch data {
      case let .text(text):
        return TextPart(text, isThought: isThought, thoughtSignature: payloadPart.thoughtSignature)
      case let .inlineData(blob):
        return InlineDataPart(
          blob,
          isThought: isThought,
          thoughtSignature: payloadPart.thoughtSignature
        )
      case let .fileData(fileData):
        return FileDataPart(
          fileData,
          isThought: isThought,
          thoughtSignature: payloadPart.thoughtSignature
        )
      case let .functionCall(functionCall):
        return FunctionCallPart(
          functionCall,
          isThought: isThought,
          thoughtSignature: payloadPart.thoughtSignature
        )
      case let .functionResponse(functionResponse):
        return FunctionResponsePart(
          functionResponse,
          isThought: isThought,
          thoughtSignature: payloadPart.thoughtSignature
        )
      case let .executableCode(executableCode):
        return ExecutableCodePart(
          GenerateContentAPI.ExecutableCode(
            language: executableCode.language,
            code: executableCode.code
          ),
          isThought: isThought,
          thoughtSignature: payloadPart.thoughtSignature
        )
      case let .codeExecutionResult(codeExecutionResult):
        return CodeExecutionResultPart(
          codeExecutionResult: codeExecutionResult,
          isThought: isThought,
          thoughtSignature: payloadPart.thoughtSignature
        )
      case .unrecognized:
        return nil
      }
    }
    convertedParts.append(contentsOf: errorParts)
    return convertedParts
  }

  /// Creates a new value from a list of ``Part``s.
  public init(role: String? = "user", parts: [any Part]) {
    var errorParts = [ErrorPart]()
    var payloadParts = [GenerateContentAPI.Part]()

    for part in parts {
      if let errorPart = part as? ErrorPart {
        errorParts.append(errorPart)
      } else if let payloadConvertible = part as? any ConvertibleToRequestPayload,
                let payload = (try? payloadConvertible.toRequestPayload()) as? GenerateContentAPI
                .Part {
        payloadParts.append(payload)
      }
    }

    internalContent = GenerateContentAPI.Content(parts: payloadParts, role: role)
    self.errorParts = errorParts
  }

  /// Creates a new value from any data interpretable as a ``Part``.
  /// See ``PartsRepresentable`` for types that can be interpreted as `Part`s.
  public init(role: String? = "user", parts: any PartsRepresentable...) {
    let content = parts.flatMap { $0.partsValue }
    self.init(role: role, parts: content)
  }

  init(role: String?, parts: [GenerateContentAPI.Part]) {
    internalContent = GenerateContentAPI.Content(parts: parts, role: role)
    errorParts = []
  }

  init(content: GenerateContentAPI.Content) {
    internalContent = content
    errorParts = []
  }
}

// MARK: - Codable Conformances

extension ModelContent: Codable {
  public init(from decoder: any Decoder) throws {
    let content = try GenerateContentAPI.Content(from: decoder)
    self.init(content: content)
  }

  public func encode(to encoder: any Encoder) throws {
    try internalContent.encode(to: encoder)
  }
}

// MARK: - Payload Convertible Conformances

extension ModelContent: ConvertibleToRequestPayload {
  func toRequestPayload() throws -> GenerateContentAPI.Content {
    return internalContent
  }
}

extension ModelContent: ConvertibleFromResponsePayload {
  init(_ responsePayload: GenerateContentAPI.Content) throws {
    self.init(content: responsePayload)
  }
}
