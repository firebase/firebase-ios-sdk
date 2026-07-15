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
package import InternalSharedDataModels


extension GeminiDataModels {
  /// An internal data model for `ToolExaAiSearch`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ToolExaAiSearch`
  /// 
  /// ExaAiSearch tool type.
  /// A tool that uses the Exa.ai search engine for grounding.
  package struct ToolExaAiSearch: Codable, Sendable, Equatable, Hashable {
    /// Required. The API key for ExaAiSearch.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The API key for ExaAiSearch.
    package let apiKey: String
    
    /// Optional. This field can be used to pass any parameter from the Exa.ai
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. This field can be used to pass any parameter from the Exa.ai
    /// Search API.
    package let customConfigs: [String: JSONValue]?
    

    /// Creates a new `ToolExaAiSearch`.
    ///
    /// - Parameters:
    ///   - apiKey: Required. The API key for ExaAiSearch. (Gemini Enterprise Agent Platform only). For more details, see ``apiKey``.
    ///   - customConfigs: Optional. This field can be used to pass any parameter from the Exa.ai (Gemini Enterprise Agent Platform only). For more details, see ``customConfigs``.
    package init(
      apiKey: String,
      customConfigs: [String: JSONValue]? = nil
    ) {
      self.apiKey = apiKey
      self.customConfigs = customConfigs
    }
    enum CodingKeys: String, CodingKey {
      case apiKey = "apiKey"
      case customConfigs = "customConfigs"
    }
  }
}