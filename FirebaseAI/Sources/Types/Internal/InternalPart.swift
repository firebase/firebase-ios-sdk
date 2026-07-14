// Copyright 2024 Google LLC
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

struct InlineData: Equatable, Sendable {
  let mimeType: String
  let data: Data

  init(data: Data, mimeType: String) {
    self.data = data
    self.mimeType = mimeType
  }
}

struct FileData: Equatable, Sendable {
  let fileURI: String
  let mimeType: String

  init(fileURI: String, mimeType: String) {
    self.fileURI = fileURI
    self.mimeType = mimeType
  }
}

struct FunctionCall: Equatable, Sendable {
  let name: String
  let args: JSONObject
  let id: String?

  init(name: String, args: JSONObject, id: String?) {
    self.name = name
    self.args = args
    self.id = id
  }
}

struct FunctionResponse: Equatable, Sendable {
  let name: String
  let response: JSONObject
  let id: String?

  init(name: String, response: JSONObject, id: String? = nil) {
    self.name = name
    self.response = response
    self.id = id
  }
}

struct ExecutableCode: Equatable, Sendable {
  struct Language: ProtoEnum, Sendable, Equatable {
    enum Kind: String {
      case unspecified = "LANGUAGE_UNSPECIFIED"
      case python = "PYTHON"
    }

    let rawValue: String

    static let unrecognizedValueMessageCode =
      AILog.MessageCode.executableCodeUnrecognizedLanguage
  }

  let language: Language?
  let code: String?

  init(language: Language, code: String) {
    self.language = language
    self.code = code
  }
}

struct CodeExecutionResult: Equatable, Sendable {
  struct Outcome: ProtoEnum, Sendable, Equatable {
    enum Kind: String {
      case unspecified = "OUTCOME_UNSPECIFIED"
      case ok = "OUTCOME_OK"
      case failed = "OUTCOME_FAILED"
      case deadlineExceeded = "OUTCOME_DEADLINE_EXCEEDED"
    }

    let rawValue: String

    static let unrecognizedValueMessageCode =
      AILog.MessageCode.codeExecutionResultUnrecognizedOutcome
  }

  let outcome: Outcome?
  let output: String?

  init(outcome: Outcome, output: String) {
    self.outcome = outcome
    self.output = output
  }
}

struct ErrorPart: Part, Error {
  let error: Error

  let isThought = false
  let thoughtSignature: String? = nil

  init(_ error: Error) {
    self.error = error
  }
}

// MARK: - Equatable Conformances

extension ErrorPart: Equatable {
  static func == (lhs: ErrorPart, rhs: ErrorPart) -> Bool {
    fatalError("Comparing ErrorParts for equality is not supported.")
  }
}

// MARK: - Mappings

extension InlineData {
  func toShared() -> SharedDataModels.Blob {
    SharedDataModels.Blob(mimeType: mimeType, data: data)
  }

  init(fromShared blob: SharedDataModels.Blob) {
    self.data = blob.data ?? Data()
    self.mimeType = blob.mimeType ?? ""
  }
}

extension FileData {
  func toShared() -> SharedDataModels.FileData {
    SharedDataModels.FileData(fileUri: fileURI, mimeType: mimeType)
  }

  init(fromShared file: SharedDataModels.FileData) {
    self.fileURI = file.fileUri ?? ""
    self.mimeType = file.mimeType ?? ""
  }
}

extension FunctionCall {
  func toGoogleAI() -> GoogleAI.FunctionCall {
    GoogleAI.FunctionCall(
      args: args.toShared(),
      id: id,
      name: name
    )
  }

  func toAgentPlatform() -> AgentPlatform.FunctionCall {
    AgentPlatform.FunctionCall(
      args: args.toShared(),
      id: id,
      name: name
    )
  }

  init(fromGoogleAI fc: GoogleAI.FunctionCall) {
    self.name = fc.name ?? ""
    self.id = fc.id
    if let args = fc.args {
      self.args = JSONObject(fromShared: args)
    } else {
      self.args = JSONObject()
    }
  }

  init(fromAgentPlatform fc: AgentPlatform.FunctionCall) {
    self.name = fc.name ?? ""
    self.id = fc.id
    if let args = fc.args {
      self.args = JSONObject(fromShared: args)
    } else {
      self.args = JSONObject()
    }
  }
}

extension FunctionResponse {
  func toGoogleAI() -> GoogleAI.FunctionResponse {
    GoogleAI.FunctionResponse(
      id: id,
      name: name,
      response: response.toShared()
    )
  }

  func toAgentPlatform() -> AgentPlatform.FunctionResponse {
    AgentPlatform.FunctionResponse(
      id: id,
      name: name,
      response: response.toShared()
    )
  }

  init(fromGoogleAI fr: GoogleAI.FunctionResponse) {
    self.name = fr.name ?? ""
    self.id = fr.id
    if let response = fr.response {
      self.response = JSONObject(fromShared: response)
    } else {
      self.response = JSONObject()
    }
  }

  init(fromAgentPlatform fr: AgentPlatform.FunctionResponse) {
    self.name = fr.name ?? ""
    self.id = fr.id
    if let response = fr.response {
      self.response = JSONObject(fromShared: response)
    } else {
      self.response = JSONObject()
    }
  }
}

extension ExecutableCode.Language {
  func toGoogleAI() -> GoogleAI.ExecutableCode.Language {
    GoogleAI.ExecutableCode.Language(rawValue: rawValue) ?? .unspecified
  }

  func toAgentPlatform() -> AgentPlatform.ExecutableCode.Language {
    AgentPlatform.ExecutableCode.Language(rawValue: rawValue) ?? .unspecified
  }

  init(fromGoogleAI lang: GoogleAI.ExecutableCode.Language) {
    self.rawValue = lang.rawValue
  }

  init(fromAgentPlatform lang: AgentPlatform.ExecutableCode.Language) {
    self.rawValue = lang.rawValue
  }
}

extension ExecutableCode {
  func toGoogleAI() -> GoogleAI.ExecutableCode {
    GoogleAI.ExecutableCode(
      code: code,
      language: language?.toGoogleAI()
    )
  }

  func toAgentPlatform() -> AgentPlatform.ExecutableCode {
    AgentPlatform.ExecutableCode(
      code: code,
      language: language?.toAgentPlatform()
    )
  }

  init(fromGoogleAI ec: GoogleAI.ExecutableCode) {
    self.code = ec.code
    self.language = ec.language.map { ExecutableCode.Language(fromGoogleAI: $0) }
  }

  init(fromAgentPlatform ec: AgentPlatform.ExecutableCode) {
    self.code = ec.code
    self.language = ec.language.map { ExecutableCode.Language(fromAgentPlatform: $0) }
  }
}

extension CodeExecutionResult.Outcome {
  func toGoogleAI() -> GoogleAI.CodeExecutionResult.Outcome {
    GoogleAI.CodeExecutionResult.Outcome(rawValue: rawValue) ?? .unspecified
  }

  func toAgentPlatform() -> AgentPlatform.CodeExecutionResult.Outcome {
    AgentPlatform.CodeExecutionResult.Outcome(rawValue: rawValue) ?? .unspecified
  }

  init(fromGoogleAI out: GoogleAI.CodeExecutionResult.Outcome) {
    self.rawValue = out.rawValue
  }

  init(fromAgentPlatform out: AgentPlatform.CodeExecutionResult.Outcome) {
    self.rawValue = out.rawValue
  }
}

extension CodeExecutionResult {
  func toGoogleAI() -> GoogleAI.CodeExecutionResult {
    GoogleAI.CodeExecutionResult(
      outcome: outcome?.toGoogleAI(),
      output: output
    )
  }

  func toAgentPlatform() -> AgentPlatform.CodeExecutionResult {
    AgentPlatform.CodeExecutionResult(
      outcome: outcome?.toAgentPlatform(),
      output: output
    )
  }

  init(fromGoogleAI cer: GoogleAI.CodeExecutionResult) {
    self.output = cer.output
    self.outcome = cer.outcome.map { CodeExecutionResult.Outcome(fromGoogleAI: $0) }
  }

  init(fromAgentPlatform cer: AgentPlatform.CodeExecutionResult) {
    self.output = cer.output
    self.outcome = cer.outcome.map { CodeExecutionResult.Outcome(fromAgentPlatform: $0) }
  }
}
