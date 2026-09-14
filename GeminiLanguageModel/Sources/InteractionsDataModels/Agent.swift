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

package import GeminiSharedDataModels

/// An agent definition for the CreateAgent API.
/// This message is the target for annotation-parser-based JSON parsing.
/// New format:
///   {
///     "id": "customer-sentinel",
///     "base_agent": "",
///     "system_instruction": "...",
///     "base_environment": { "type": "remote", "sources": [...] },
///     "tools": [ {"type": "code_execution"} ]
///   }
package struct Agent: Codable, Sendable, Equatable, Hashable {

  /// Configuration parameters for the agent.
  package let agentConfig: JSONValue?

  /// The base agent to extend.
  package let baseAgent: String?

  /// The environment configuration for the agent.
  package let baseEnvironment: JSONValue?

  /// Agent description for developers to quickly read and understand.
  package let description: String?

  /// The unique identifier for the agent.
  package let id: String?

  /// System instruction for the agent.
  package let systemInstruction: String?

  /// The tools available to the agent.
  package let tools: [AgentTool]?

  /// Creates a new `Agent`.
  ///
  /// - Parameters:
  ///   - agentConfig: Configuration parameters for the agent.
  ///   - baseAgent: The base agent to extend.
  ///   - baseEnvironment: The environment configuration for the agent.
  ///   - description: Agent description for developers to quickly read and understand.
  ///   - id: The unique identifier for the agent.
  ///   - systemInstruction: System instruction for the agent.
  ///   - tools: The tools available to the agent.
  package init(
    agentConfig: JSONValue? = nil,
    baseAgent: String? = nil,
    baseEnvironment: JSONValue? = nil,
    description: String? = nil,
    id: String? = nil,
    systemInstruction: String? = nil,
    tools: [AgentTool]? = nil
  ) {
    self.agentConfig = agentConfig
    self.baseAgent = baseAgent
    self.baseEnvironment = baseEnvironment
    self.description = description
    self.id = id
    self.systemInstruction = systemInstruction
    self.tools = tools
  }
  enum CodingKeys: String, CodingKey {
    case agentConfig = "agent_config"
    case baseAgent = "base_agent"
    case baseEnvironment = "base_environment"
    case description = "description"
    case id = "id"
    case systemInstruction = "system_instruction"
    case tools = "tools"
  }
}
