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


extension AgentPlatform {
  /// ParallelAiSearch tool type. A tool that uses the Parallel.ai search engine for grounding.
  public struct ToolParallelAiSearch: Codable, Sendable, Equatable, Hashable {
    /// Optional. The API key for ParallelAiSearch. If an API key is not provided, the system will attempt to verify access by checking for an active Parallel.ai subscription through the Google Cloud Marketplace. See https://docs.parallel.ai/search/search-quickstart for more details.
    public var apiKey: String?
    
    /// Optional. Custom configs for ParallelAiSearch. This field can be used to pass any parameter from the Parallel.ai Search API. See the Parallel.ai documentation for the full list of available parameters and their usage: https://docs.parallel.ai/api-reference/search-beta/search Currently only `source_policy`, `excerpts`, `max_results`, `mode`, `fetch_policy` can be set via this field. For example: { "source_policy": { "include_domains": ["google.com", "wikipedia.org"], "exclude_domains": ["example.com"] }, "fetch_policy": { "max_age_seconds": 3600 } }
    public var customConfigs: [String: JSONValue]?
    
    /// Optional. Deprecated: Use `enable_zero_data_retention` instead. Instructs Vertex Grounding to use Parallel's Zero Data Retention Marketplace product. If this value is "false" or omitted, the Parallel Web Search for Grounding standard subscription will be used. If this value is "true", the Parallel Web Search for Grounding - ZDR subscription will be used.
    @available(*, deprecated)
    public var enableDataRetention: Bool?
    
    /// Optional. Instructs Vertex Grounding to use Parallel's Zero Data Retention Marketplace product. If this value is "false" or omitted, the Parallel Web Search for Grounding standard subscription will be used. If this value is "true", the Parallel Web Search for Grounding - ZDR subscription will be used.
    public var enableZeroDataRetention: Bool?
    
    /// Creates a new `ToolParallelAiSearch`.
    public init(
      apiKey: String? = nil,
      customConfigs: [String: JSONValue]? = nil,
      enableDataRetention: Bool? = nil,
      enableZeroDataRetention: Bool? = nil
    ) {
      self.apiKey = apiKey
      self.customConfigs = customConfigs
      self.enableDataRetention = enableDataRetention
      self.enableZeroDataRetention = enableZeroDataRetention
    }
    enum CodingKeys: String, CodingKey {
      case apiKey = "apiKey"
      case customConfigs = "customConfigs"
      case enableDataRetention = "enableDataRetention"
      case enableZeroDataRetention = "enableZeroDataRetention"
    }
  }
}