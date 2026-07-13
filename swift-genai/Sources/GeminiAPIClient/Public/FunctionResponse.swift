// Copyright 2026 Google LLC
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
public import SharedDataModels
package import GoogleAIDataModels
package import AgentPlatformDataModels

/// Represents a function response.
public struct FunctionResponse: Codable, Sendable, Equatable, Hashable {
  public var name: String?
  public var response: [String: JSONValue]?
  public var id: String?
  public var parts: [FunctionResponsePart]?
  public var scheduling: Scheduling?
  /// - Note: Only supported on GoogleAI backend.
  public var willContinue: Bool?

  public init(
    name: String? = nil,
    response: [String: JSONValue]? = nil,
    id: String? = nil,
    parts: [FunctionResponsePart]? = nil,
    scheduling: Scheduling? = nil,
    willContinue: Bool? = nil
  ) {
    self.name = name
    self.response = response
    self.id = id
    self.parts = parts
    self.scheduling = scheduling
    self.willContinue = willContinue
  }
}

public struct FunctionResponsePart: Codable, Sendable, Equatable, Hashable {
  public var inlineData: FunctionResponseBlob?
  /// - Note: Only supported on AgentPlatform backend.
  public var fileData: FunctionResponseFileData?

  public init(
    inlineData: FunctionResponseBlob? = nil,
    fileData: FunctionResponseFileData? = nil
  ) {
    self.inlineData = inlineData
    self.fileData = fileData
  }
}

public struct FunctionResponseBlob: Codable, Sendable, Equatable, Hashable {
  public var data: String?
  public var mimeType: String?
  /// - Note: Only supported on AgentPlatform backend.
  public var displayName: String?

  public init(data: String? = nil, mimeType: String? = nil, displayName: String? = nil) {
    self.data = data
    self.mimeType = mimeType
    self.displayName = displayName
  }
}

public struct FunctionResponseFileData: Codable, Sendable, Equatable, Hashable {
  public var fileUri: String?
  public var mimeType: String?
  /// - Note: Only supported on AgentPlatform backend.
  public var displayName: String?

  public init(fileUri: String? = nil, mimeType: String? = nil, displayName: String? = nil) {
    self.fileUri = fileUri
    self.mimeType = mimeType
    self.displayName = displayName
  }
}

public enum Scheduling: Codable, Sendable, Equatable, Hashable {
  case whenIdle
  case silent
  case interrupt
  case unrecognized(_ value: String)
}

// MARK: - GoogleAI Mappings

extension FunctionResponse {
  package func toGoogleAI() -> GoogleAI.FunctionResponse {
    GoogleAI.FunctionResponse(
      id: id,
      name: name,
      parts: parts?.map { $0.toGoogleAI() },
      response: response,
      scheduling: scheduling?.toGoogleAI(),
      willContinue: willContinue
    )
  }

  package init(fromGoogleAI fr: GoogleAI.FunctionResponse) {
    self.id = fr.id
    self.name = fr.name
    self.parts = fr.parts?.map { FunctionResponsePart(fromGoogleAI: $0) }
    self.response = fr.response
    self.scheduling = fr.scheduling.map { Scheduling(fromGoogleAI: $0) }
    self.willContinue = fr.willContinue
  }
}

extension FunctionResponsePart {
  package func toGoogleAI() -> GoogleAI.FunctionResponsePart {
    GoogleAI.FunctionResponsePart(inlineData: inlineData?.toGoogleAI())
  }

  package init(fromGoogleAI frp: GoogleAI.FunctionResponsePart) {
    self.inlineData = frp.inlineData.map { FunctionResponseBlob(fromGoogleAI: $0) }
    self.fileData = nil
  }
}

extension FunctionResponseBlob {
  package func toGoogleAI() -> GoogleAI.FunctionResponseBlob {
    GoogleAI.FunctionResponseBlob(data: data, mimeType: mimeType)
  }

  package init(fromGoogleAI frb: GoogleAI.FunctionResponseBlob) {
    self.data = frb.data
    self.mimeType = frb.mimeType
    self.displayName = nil
  }
}

extension Scheduling {
  package func toGoogleAI() -> GoogleAI.FunctionResponse.Scheduling {
    switch self {
    case .whenIdle: .whenIdle
    case .silent: .silent
    case .interrupt: .interrupt
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromGoogleAI sched: GoogleAI.FunctionResponse.Scheduling) {
    switch sched {
    case .whenIdle: self = .whenIdle
    case .silent: self = .silent
    case .interrupt: self = .interrupt
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}

// MARK: - AgentPlatform Mappings

extension FunctionResponse {
  package func toAgentPlatform() -> AgentPlatform.FunctionResponse {
    AgentPlatform.FunctionResponse(
      id: id,
      name: name,
      parts: parts?.map { $0.toAgentPlatform() },
      response: response,
      scheduling: scheduling?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform fr: AgentPlatform.FunctionResponse) {
    self.id = fr.id
    self.name = fr.name
    self.parts = fr.parts?.map { FunctionResponsePart(fromAgentPlatform: $0) }
    self.response = fr.response
    self.scheduling = fr.scheduling.map { Scheduling(fromAgentPlatform: $0) }
    self.willContinue = nil
  }
}

extension FunctionResponsePart {
  package func toAgentPlatform() -> AgentPlatform.FunctionResponsePart {
    AgentPlatform.FunctionResponsePart(
      fileData: fileData?.toAgentPlatform(),
      inlineData: inlineData?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform frp: AgentPlatform.FunctionResponsePart) {
    self.inlineData = frp.inlineData.map { FunctionResponseBlob(fromAgentPlatform: $0) }
    self.fileData = frp.fileData.map { FunctionResponseFileData(fromAgentPlatform: $0) }
  }
}

extension FunctionResponseBlob {
  package func toAgentPlatform() -> AgentPlatform.FunctionResponseBlob {
    AgentPlatform.FunctionResponseBlob(data: data, displayName: displayName, mimeType: mimeType)
  }

  package init(fromAgentPlatform frb: AgentPlatform.FunctionResponseBlob) {
    self.data = frb.data
    self.mimeType = frb.mimeType
    self.displayName = frb.displayName
  }
}

extension FunctionResponseFileData {
  package func toAgentPlatform() -> AgentPlatform.FunctionResponseFileData {
    AgentPlatform.FunctionResponseFileData(displayName: displayName, fileUri: fileUri, mimeType: mimeType)
  }

  package init(fromAgentPlatform frfd: AgentPlatform.FunctionResponseFileData) {
    self.fileUri = frfd.fileUri
    self.mimeType = frfd.mimeType
    self.displayName = frfd.displayName
  }
}

extension Scheduling {
  package func toAgentPlatform() -> AgentPlatform.FunctionResponse.Scheduling {
    switch self {
    case .whenIdle: .whenIdle
    case .silent: .silent
    case .interrupt: .interrupt
    case .unrecognized(let val): .unrecognized(val)
    }
  }

  package init(fromAgentPlatform sched: AgentPlatform.FunctionResponse.Scheduling) {
    switch sched {
    case .whenIdle: self = .whenIdle
    case .silent: self = .silent
    case .interrupt: self = .interrupt
    case .unrecognized(let val): self = .unrecognized(val)
    }
  }
}
