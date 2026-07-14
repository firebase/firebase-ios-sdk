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


extension GeminiDataModels {
  /// Tool details that the model may use to generate response. A `Tool` is a piece of code that enables the system to interact with external systems to perform an action, or set of actions, outside of knowledge and scope of the model. A Tool object should contain exactly one type of Tool.
  package struct Tool: Codable, Sendable, Equatable, Hashable {
    /// Optional. A list of user-provided functions for function calling. For functions whose names are listed in the template frontmatter, the model may decide to call a subset of these functions by populating `FunctionCall` in the response. User should provide a `FunctionResponse` for each function call in the next turn.
    package let templateFunctions: [TemplateFunction]?
    
    /// Optional. Tool to retrieve public maps data for grounding, powered by Google.
    package let googleMaps: GoogleMaps?
    
    /// Creates a new `Tool`.
    package init(
      templateFunctions: [TemplateFunction]? = nil,
      googleMaps: GoogleMaps? = nil
    ) {
      self.templateFunctions = templateFunctions
      self.googleMaps = googleMaps
    }
    enum CodingKeys: String, CodingKey {
      case templateFunctions = "templateFunctions"
      case googleMaps = "googleMaps"
    }
  }
}