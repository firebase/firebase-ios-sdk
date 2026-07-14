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
package import InternalGoogleAIDataModels
package import InternalAgentPlatformDataModels

/// Tool config. This config is shared for all tools provided in the request.
public struct ToolConfig: Codable, Sendable, Equatable, Hashable {
  /// Optional. Function calling config.
  public var functionCallingConfig: FunctionCallingConfig?

  /// Optional. Retrieval config.
  public var retrievalConfig: RetrievalConfig?

  /// Optional. If true, the API response will include the server-side tool calls and responses.
  /// - Note: Only supported on GoogleAI backend.
  public var includeServerSideToolInvocations: Bool?

  public init(
    functionCallingConfig: FunctionCallingConfig? = nil,
    retrievalConfig: RetrievalConfig? = nil,
    includeServerSideToolInvocations: Bool? = nil
  ) {
    self.functionCallingConfig = functionCallingConfig
    self.retrievalConfig = retrievalConfig
    self.includeServerSideToolInvocations = includeServerSideToolInvocations
  }
}

/// Configuration for retrieval.
public struct RetrievalConfig: Codable, Sendable, Equatable, Hashable {
  public var languageCode: String?
  public var latLng: LatLng?

  public init(languageCode: String? = nil, latLng: LatLng? = nil) {
    self.languageCode = languageCode
    self.latLng = latLng
  }
}

/// Represents a latitude/longitude pair.
public struct LatLng: Codable, Sendable, Equatable, Hashable {
  public var latitude: Double?
  public var longitude: Double?

  public init(latitude: Double? = nil, longitude: Double? = nil) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

// MARK: - GoogleAI Mappings

extension ToolConfig {
  package func toGoogleAI() -> GoogleAI.ToolConfig {
    GoogleAI.ToolConfig(
      functionCallingConfig: functionCallingConfig?.toGoogleAI(),
      includeServerSideToolInvocations: includeServerSideToolInvocations,
      retrievalConfig: retrievalConfig?.toGoogleAI()
    )
  }

  package init(fromGoogleAI tc: GoogleAI.ToolConfig) {
    self.functionCallingConfig = tc.functionCallingConfig.map { FunctionCallingConfig(fromGoogleAI: $0) }
    self.includeServerSideToolInvocations = tc.includeServerSideToolInvocations
    self.retrievalConfig = tc.retrievalConfig.map { RetrievalConfig(fromGoogleAI: $0) }
  }
}

extension RetrievalConfig {
  package func toGoogleAI() -> GoogleAI.RetrievalConfig {
    GoogleAI.RetrievalConfig(
      languageCode: languageCode,
      latLng: latLng?.toGoogleAI()
    )
  }

  package init(fromGoogleAI rc: GoogleAI.RetrievalConfig) {
    self.languageCode = rc.languageCode
    self.latLng = rc.latLng.map { LatLng(fromGoogleAI: $0) }
  }
}

extension LatLng {
  package func toGoogleAI() -> GoogleAI.LatLng {
    GoogleAI.LatLng(latitude: latitude, longitude: longitude)
  }

  package init(fromGoogleAI ll: GoogleAI.LatLng) {
    self.latitude = ll.latitude
    self.longitude = ll.longitude
  }
}

// MARK: - AgentPlatform Mappings

extension ToolConfig {
  package func toAgentPlatform() -> AgentPlatform.ToolConfig {
    AgentPlatform.ToolConfig(
      functionCallingConfig: functionCallingConfig?.toAgentPlatform(),
      retrievalConfig: retrievalConfig?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform tc: AgentPlatform.ToolConfig) {
    self.functionCallingConfig = tc.functionCallingConfig.map { FunctionCallingConfig(fromAgentPlatform: $0) }
    self.retrievalConfig = tc.retrievalConfig.map { RetrievalConfig(fromAgentPlatform: $0) }
    self.includeServerSideToolInvocations = nil
  }
}

extension RetrievalConfig {
  package func toAgentPlatform() -> AgentPlatform.RetrievalConfig {
    AgentPlatform.RetrievalConfig(
      languageCode: languageCode,
      latLng: latLng?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform rc: AgentPlatform.RetrievalConfig) {
    self.languageCode = rc.languageCode
    self.latLng = rc.latLng.map { LatLng(fromAgentPlatform: $0) }
  }
}

extension LatLng {
  package func toAgentPlatform() -> AgentPlatform.GoogleTypeLatLng {
    AgentPlatform.GoogleTypeLatLng(latitude: latitude, longitude: longitude)
  }

  package init(fromAgentPlatform ll: AgentPlatform.GoogleTypeLatLng) {
    self.latitude = ll.latitude
    self.longitude = ll.longitude
  }
}
