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

// MARK: - GeminiTool

/// Tool details that the model may use to generate a response.
public struct GeminiTool: Codable, Sendable, Equatable, Hashable {
  /// Enables the model to execute code as part of generation.
  public var codeExecution: CodeExecutionTool?

  /// A list of function declarations available to the model for function calling.
  public var functionDeclarations: [FunctionDeclaration]?

  /// Tool to support Google Search in Model. Powered by Google.
  public var googleSearch: GoogleSearchTool?

  public init(
    codeExecution: CodeExecutionTool? = nil,
    functionDeclarations: [FunctionDeclaration]? = nil,
    googleSearch: GoogleSearchTool? = nil
  ) {
    self.codeExecution = codeExecution
    self.functionDeclarations = functionDeclarations
    self.googleSearch = googleSearch
  }
}

// MARK: - CodeExecutionTool

public struct CodeExecutionTool: Codable, Sendable, Equatable, Hashable {
  public init() {}
}

// MARK: - GoogleSearchTool

public struct GoogleSearchTool: Codable, Sendable, Equatable, Hashable {
  public init() {}
}

// MARK: - GoogleAI Mappings

extension GeminiTool {
  package func toGoogleAI() -> GoogleAI.Tool {
    GoogleAI.Tool(
      codeExecution: codeExecution?.toGoogleAI(),
      functionDeclarations: functionDeclarations?.map { $0.toGoogleAI() },
      googleSearch: googleSearch?.toGoogleAI()
    )
  }

  package init(fromGoogleAI tool: GoogleAI.Tool) {
    self.codeExecution = tool.codeExecution.map { CodeExecutionTool(fromGoogleAI: $0) }
    self.functionDeclarations = tool.functionDeclarations?.map { FunctionDeclaration(fromGoogleAI: $0) }
    self.googleSearch = tool.googleSearch.map { GoogleSearchTool(fromGoogleAI: $0) }
  }
}

extension CodeExecutionTool {
  package func toGoogleAI() -> GoogleAI.CodeExecution {
    GoogleAI.CodeExecution()
  }
  package init(fromGoogleAI ce: GoogleAI.CodeExecution) {}
}

extension GoogleSearchTool {
  package func toGoogleAI() -> GoogleAI.GoogleSearch {
    GoogleAI.GoogleSearch()
  }
  package init(fromGoogleAI gs: GoogleAI.GoogleSearch) {}
}

// MARK: - AgentPlatform Mappings

extension GeminiTool {
  package func toAgentPlatform() -> AgentPlatform.Tool {
    AgentPlatform.Tool(
      codeExecution: codeExecution?.toAgentPlatform(),
      functionDeclarations: functionDeclarations?.map { $0.toAgentPlatform() },
      googleSearch: googleSearch?.toAgentPlatform()
    )
  }

  package init(fromAgentPlatform tool: AgentPlatform.Tool) {
    self.codeExecution = tool.codeExecution.map { CodeExecutionTool(fromAgentPlatform: $0) }
    self.functionDeclarations = tool.functionDeclarations?.map { FunctionDeclaration(fromAgentPlatform: $0) }
    self.googleSearch = tool.googleSearch.map { GoogleSearchTool(fromAgentPlatform: $0) }
  }
}

extension CodeExecutionTool {
  package func toAgentPlatform() -> AgentPlatform.ToolCodeExecution {
    AgentPlatform.ToolCodeExecution()
  }
  package init(fromAgentPlatform ce: AgentPlatform.ToolCodeExecution) {}
}

extension GoogleSearchTool {
  package func toAgentPlatform() -> AgentPlatform.ToolGoogleSearch {
    AgentPlatform.ToolGoogleSearch()
  }
  package init(fromAgentPlatform gs: AgentPlatform.ToolGoogleSearch) {}
}
