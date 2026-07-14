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
import GoogleAIDataModels
import AgentPlatformDataModels

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

// MARK: - Mappings

extension InternalPart {
  func toGoogleAI() -> GoogleAI.Part {
    var thoughtBool: Bool? = nil
    if let isThought = isThought {
      thoughtBool = isThought
    }
    switch data {
    case let .text(text):
      return GoogleAI.Part(text: text, thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .inlineData(blob):
      return GoogleAI.Part(inlineData: blob.toShared(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .fileData(file):
      return GoogleAI.Part(fileData: file.toShared(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .functionCall(fc):
      return GoogleAI.Part(functionCall: fc.toGoogleAI(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .functionResponse(fr):
      return GoogleAI.Part(functionResponse: fr.toGoogleAI(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .executableCode(ec):
      return GoogleAI.Part(executableCode: ec.toGoogleAI(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .codeExecutionResult(cer):
      return GoogleAI.Part(codeExecutionResult: cer.toGoogleAI(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case .none:
      return GoogleAI.Part(thought: thoughtBool, thoughtSignature: thoughtSignature)
    }
  }

  func toAgentPlatform() -> AgentPlatform.Part {
    var thoughtBool: Bool? = nil
    if let isThought = isThought {
      thoughtBool = isThought
    }
    switch data {
    case let .text(text):
      return AgentPlatform.Part(text: text, thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .inlineData(blob):
      return AgentPlatform.Part(inlineData: blob.toShared(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .fileData(file):
      return AgentPlatform.Part(fileData: file.toShared(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .functionCall(fc):
      return AgentPlatform.Part(functionCall: fc.toAgentPlatform(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .functionResponse(fr):
      return AgentPlatform.Part(functionResponse: fr.toAgentPlatform(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .executableCode(ec):
      return AgentPlatform.Part(executableCode: ec.toAgentPlatform(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case let .codeExecutionResult(cer):
      return AgentPlatform.Part(codeExecutionResult: cer.toAgentPlatform(), thought: thoughtBool, thoughtSignature: thoughtSignature)
    case .none:
      return AgentPlatform.Part(thought: thoughtBool, thoughtSignature: thoughtSignature)
    }
  }

  init(fromGoogleAI part: GoogleAI.Part) {
    self.isThought = part.thought
    self.thoughtSignature = part.thoughtSignature
    
    if let text = part.text {
      self.data = .text(text)
    } else if let inlineData = part.inlineData {
      self.data = .inlineData(InlineData(fromShared: inlineData))
    } else if let fileData = part.fileData {
      self.data = .fileData(FileData(fromShared: fileData))
    } else if let functionCall = part.functionCall {
      self.data = .functionCall(FunctionCall(fromGoogleAI: functionCall))
    } else if let functionResponse = part.functionResponse {
      self.data = .functionResponse(FunctionResponse(fromGoogleAI: functionResponse))
    } else if let executableCode = part.executableCode {
      self.data = .executableCode(ExecutableCode(fromGoogleAI: executableCode))
    } else if let codeExecutionResult = part.codeExecutionResult {
      self.data = .codeExecutionResult(CodeExecutionResult(fromGoogleAI: codeExecutionResult))
    } else {
      self.data = nil
    }
  }

  init(fromAgentPlatform part: AgentPlatform.Part) {
    self.isThought = part.thought
    self.thoughtSignature = part.thoughtSignature
    
    if let text = part.text {
      self.data = .text(text)
    } else if let inlineData = part.inlineData {
      self.data = .inlineData(InlineData(fromShared: inlineData))
    } else if let fileData = part.fileData {
      self.data = .fileData(FileData(fromShared: fileData))
    } else if let functionCall = part.functionCall {
      self.data = .functionCall(FunctionCall(fromAgentPlatform: functionCall))
    } else if let functionResponse = part.functionResponse {
      self.data = .functionResponse(FunctionResponse(fromAgentPlatform: functionResponse))
    } else if let executableCode = part.executableCode {
      self.data = .executableCode(ExecutableCode(fromAgentPlatform: executableCode))
    } else if let codeExecutionResult = part.codeExecutionResult {
      self.data = .codeExecutionResult(CodeExecutionResult(fromAgentPlatform: codeExecutionResult))
    } else {
      self.data = nil
    }
  }
}

extension ModelContent {
  package func toGoogleAI() -> GoogleAI.Content {
    GoogleAI.Content(
      parts: internalParts.map { $0.toGoogleAI() },
      role: role
    )
  }

  package func toAgentPlatform() -> AgentPlatform.Content {
    AgentPlatform.Content(
      parts: internalParts.map { $0.toAgentPlatform() },
      role: role
    )
  }

  package init(fromGoogleAI content: GoogleAI.Content) {
    self.role = content.role
    self.internalParts = content.parts?.map { InternalPart(fromGoogleAI: $0) } ?? []
  }

  package init(fromAgentPlatform content: AgentPlatform.Content) {
    self.role = content.role
    self.internalParts = content.parts?.map { InternalPart(fromAgentPlatform: $0) } ?? []
  }
}
