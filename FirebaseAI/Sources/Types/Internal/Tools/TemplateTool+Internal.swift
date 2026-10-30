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

extension TemplateTool {
  /// Tool details that the model may use to generate a response.
  ///
  /// A tool is a piece of code that enables the system to interact with external systems to perform
  /// an action, or set of actions, outside of knowledge and scope of the model. A tool object
  /// should
  /// contain exactly one type of tool.
  struct Internal: Sendable {
    /// A list of user-provided functions for function calling.
    ///
    /// For functions whose names are listed in the template frontmatter, the model may decide to
    /// call a subset of these functions by populating `FunctionCall` in the response. The user
    /// should
    /// provide a `FunctionResponse` for each function call in the next turn.
    let templateFunctions: [TemplateFunction]?

    /// A Google Maps tool.
    let googleMaps: GoogleMaps?
  }

  func toInternal() throws -> Internal {
    return try Internal(
      templateFunctions: functionDeclarations?.map { try TemplateFunction($0) },
      googleMaps: googleMaps
    )
  }
}

extension TemplateTool.Internal: Encodable {}
