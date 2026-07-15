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
  /// An internal data model for `GoogleSearch`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaToolGoogleSearch`
  /// 
  /// GoogleSearch tool type.
  /// Tool to support Google Search in Model. Powered by Google.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ToolGoogleSearch`
  /// 
  /// GoogleSearch tool type.
  /// Tool to support Google Search in Model. Powered by Google.
  package struct GoogleSearch: Codable, Sendable, Equatable, Hashable {
    /// Optional. Filter search results to a specific time range.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Filter search results to a specific time range.
    /// If customers set a start time, they must set an end time (and vice
    /// versa).
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let timeRangeFilter: Interval?
    
    /// Optional. The set of search types to enable. If not set, web search is
    /// enabled by default.
    package let searchTypes: SearchTypes?
    
    /// Optional. List of domains to be excluded from the search results.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. List of domains to be excluded from the search results.
    /// The default limit is 2000 domains.
    /// Example: ["amazon.com", "facebook.com"].
    package let excludeDomains: [String]?
    
    /// Optional. Sites with confidence level chosen & above this value will be blocked
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Sites with confidence level chosen & above this value will be blocked
    /// from the search results.
    package let blockingConfidence: BlockingConfidence?
    

    /// Creates a new `GoogleSearch`.
    ///
    /// - Parameters:
    ///   - timeRangeFilter: Optional. Filter search results to a specific time range. (Gemini Developer API only). For more details, see ``timeRangeFilter``.
    ///   - searchTypes: Optional. The set of search types to enable. If not set, web search is
    ///   - excludeDomains: Optional. List of domains to be excluded from the search results. (Gemini Enterprise Agent Platform only). For more details, see ``excludeDomains``.
    ///   - blockingConfidence: Optional. Sites with confidence level chosen & above this value will be blocked (Gemini Enterprise Agent Platform only). For more details, see ``blockingConfidence``.
    package init(
      timeRangeFilter: Interval? = nil,
      searchTypes: SearchTypes? = nil,
      excludeDomains: [String]? = nil,
      blockingConfidence: BlockingConfidence? = nil
    ) {
      self.timeRangeFilter = timeRangeFilter
      self.searchTypes = searchTypes
      self.excludeDomains = excludeDomains
      self.blockingConfidence = blockingConfidence
    }
    enum CodingKeys: String, CodingKey {
      case timeRangeFilter = "timeRangeFilter"
      case searchTypes = "searchTypes"
      case excludeDomains = "excludeDomains"
      case blockingConfidence = "blockingConfidence"
    }
  }
}