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
  /// An internal data model for `ToolParallelAiSearch`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ToolParallelAiSearch`
  /// 
  /// ParallelAiSearch tool type.
  /// A tool that uses the Parallel.ai search engine for grounding.
  package struct ToolParallelAiSearch: Codable, Sendable, Equatable, Hashable {
    /// Optional. The API key for ParallelAiSearch.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The API key for ParallelAiSearch.
    /// If an API key is not provided, the system will attempt to verify access
    /// by checking for an active Parallel.ai subscription through the Google
    /// Cloud Marketplace.
    /// See https://docs.parallel.ai/search/search-quickstart for more details.
    package let apiKey: String?
    
    /// Optional. Deprecated: Use `enable_zero_data_retention` instead.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Deprecated: Use `enable_zero_data_retention` instead.
    /// Instructs Vertex Grounding to use Parallel's Zero Data Retention
    /// Marketplace product.
    /// If this value is "false" or omitted, the Parallel Web Search for
    /// Grounding standard subscription will be used.
    /// If this value is "true", the Parallel Web Search for
    /// Grounding - ZDR subscription will be used.
    @available(*, deprecated)
    package let enableDataRetention: Bool?
    
    /// Optional. Instructs Vertex Grounding to use Parallel's Zero Data Retention
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Instructs Vertex Grounding to use Parallel's Zero Data Retention
    /// Marketplace product.
    /// If this value is "false" or omitted, the Parallel Web Search for
    /// Grounding standard subscription will be used.
    /// If this value is "true", the Parallel Web Search for
    /// Grounding - ZDR subscription will be used.
    package let enableZeroDataRetention: Bool?
    
    /// Optional. Custom configs for ParallelAiSearch.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Custom configs for ParallelAiSearch.
    /// This field can be used to pass any parameter from the Parallel.ai
    /// Search API.
    /// See the Parallel.ai documentation for the full list of available
    /// parameters and their usage:
    /// https://docs.parallel.ai/api-reference/search-beta/search
    /// Currently only `source_policy`, `excerpts`, `max_results`, `mode`,
    /// `fetch_policy` can be set via this field. For example:
    /// {
    ///   "source_policy": {
    ///     "include_domains": ["google.com", "wikipedia.org"],
    ///     "exclude_domains": ["example.com"]
    ///   },
    ///   "fetch_policy": {
    ///     "max_age_seconds": 3600
    ///   }
    /// }
    package let customConfigs: [String: JSONValue]?
    

    /// Creates a new `ToolParallelAiSearch`.
    ///
    /// - Parameters:
    ///   - apiKey: Optional. The API key for ParallelAiSearch. (Gemini Enterprise Agent Platform only). For more details, see ``apiKey``.
    ///   - enableDataRetention: Optional. Deprecated: Use `enable_zero_data_retention` instead. (Gemini Enterprise Agent Platform only). For more details, see ``enableDataRetention``.
    ///   - enableZeroDataRetention: Optional. Instructs Vertex Grounding to use Parallel's Zero Data Retention (Gemini Enterprise Agent Platform only). For more details, see ``enableZeroDataRetention``.
    ///   - customConfigs: Optional. Custom configs for ParallelAiSearch. (Gemini Enterprise Agent Platform only). For more details, see ``customConfigs``.
    package init(
      apiKey: String? = nil,
      enableDataRetention: Bool? = nil,
      enableZeroDataRetention: Bool? = nil,
      customConfigs: [String: JSONValue]? = nil
    ) {
      self.apiKey = apiKey
      self.enableDataRetention = enableDataRetention
      self.enableZeroDataRetention = enableZeroDataRetention
      self.customConfigs = customConfigs
    }
    enum CodingKeys: String, CodingKey {
      case apiKey = "apiKey"
      case enableDataRetention = "enableDataRetention"
      case enableZeroDataRetention = "enableZeroDataRetention"
      case customConfigs = "customConfigs"
    }
  }
}