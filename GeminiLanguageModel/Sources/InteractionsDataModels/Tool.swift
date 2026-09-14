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

/// A tool that can be used by the model.
package enum Tool: Codable, Sendable, Equatable, Hashable {

  /// A tool that can be used by the model to execute code.
  case codeExecution(CodeExecution)

  /// A tool that can be used by the model to interact with the computer.
  case computerUse(ComputerUse)

  /// A tool that can be used by the model to search files.
  case fileSearch(FileSearch)

  /// A tool that can be used by the model.
  case function(Function)

  /// A tool that can be used by the model to call Google Maps.
  case googleMaps(GoogleMaps)

  /// A tool that can be used by the model to search Google.
  case googleSearch(GoogleSearch)

  /// A MCPServer is a server that can be called by the model to perform actions.
  case mCPServer(MCPServer)

  /// A tool that can be used by the model to fetch URL context.
  case uRLContext(URLContext)

  /// Unrecognized case.
  case unrecognized(JSONValue)

  private enum CodingKeys: String, CodingKey {
    case discriminator = "type"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let discValue = try container.decode(String.self, forKey: .discriminator)
    switch discValue {
    case "code_execution":
      let val = try CodeExecution(from: decoder)
      self = .codeExecution(val)
    case "computer_use":
      let val = try ComputerUse(from: decoder)
      self = .computerUse(val)
    case "file_search":
      let val = try FileSearch(from: decoder)
      self = .fileSearch(val)
    case "function":
      let val = try Function(from: decoder)
      self = .function(val)
    case "google_maps":
      let val = try GoogleMaps(from: decoder)
      self = .googleMaps(val)
    case "google_search":
      let val = try GoogleSearch(from: decoder)
      self = .googleSearch(val)
    case "mcp_server":
      let val = try MCPServer(from: decoder)
      self = .mCPServer(val)
    case "url_context":
      let val = try URLContext(from: decoder)
      self = .uRLContext(val)
    default:
      let val = try JSONValue(from: decoder)
      self = .unrecognized(val)
    }
  }

  package func encode(to encoder: any Encoder) throws {
    switch self {
    case .codeExecution(let val):
      try val.encode(to: encoder)
    case .computerUse(let val):
      try val.encode(to: encoder)
    case .fileSearch(let val):
      try val.encode(to: encoder)
    case .function(let val):
      try val.encode(to: encoder)
    case .googleMaps(let val):
      try val.encode(to: encoder)
    case .googleSearch(let val):
      try val.encode(to: encoder)
    case .mCPServer(let val):
      try val.encode(to: encoder)
    case .uRLContext(let val):
      try val.encode(to: encoder)
    case .unrecognized(let val):
      try val.encode(to: encoder)
    }
  }
}
