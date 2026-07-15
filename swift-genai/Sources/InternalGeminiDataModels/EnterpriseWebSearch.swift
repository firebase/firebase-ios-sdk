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
  /// An internal data model for `EnterpriseWebSearch`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1EnterpriseWebSearch`
  /// 
  /// Tool to search public web data, powered by Vertex AI Search and Sec4
  /// compliance.
  package struct EnterpriseWebSearch: Codable, Sendable, Equatable, Hashable {
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
    

    /// Creates a new `EnterpriseWebSearch`.
    ///
    /// - Parameters:
    ///   - excludeDomains: Optional. List of domains to be excluded from the search results. (Gemini Enterprise Agent Platform only). For more details, see ``excludeDomains``.
    ///   - blockingConfidence: Optional. Sites with confidence level chosen & above this value will be blocked (Gemini Enterprise Agent Platform only). For more details, see ``blockingConfidence``.
    package init(
      excludeDomains: [String]? = nil,
      blockingConfidence: BlockingConfidence? = nil
    ) {
      self.excludeDomains = excludeDomains
      self.blockingConfidence = blockingConfidence
    }
    enum CodingKeys: String, CodingKey {
      case excludeDomains = "excludeDomains"
      case blockingConfidence = "blockingConfidence"
    }
  }
}