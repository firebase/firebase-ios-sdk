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


extension AgentPlatform {
  /// GoogleSearch tool type. Tool to support Google Search in Model. Powered by Google.
  public struct ToolGoogleSearch: Codable, Sendable, Equatable, Hashable {
    /// Optional. Sites with confidence level chosen & above this value will be blocked from the search results.
    public var blockingConfidence: BlockingConfidence?
    
    /// Optional. List of domains to be excluded from the search results. The default limit is 2000 domains. Example: ["amazon.com", "facebook.com"].
    public var excludeDomains: [String]?
    
    /// Optional. The set of search types to enable. If not set, web search is enabled by default.
    public var searchTypes: ToolGoogleSearchSearchTypes?
    
    /// Creates a new `ToolGoogleSearch`.
    public init(
      blockingConfidence: BlockingConfidence? = nil,
      excludeDomains: [String]? = nil,
      searchTypes: ToolGoogleSearchSearchTypes? = nil
    ) {
      self.blockingConfidence = blockingConfidence
      self.excludeDomains = excludeDomains
      self.searchTypes = searchTypes
    }
    enum CodingKeys: String, CodingKey {
      case blockingConfidence = "blockingConfidence"
      case excludeDomains = "excludeDomains"
      case searchTypes = "searchTypes"
    }
  }
}