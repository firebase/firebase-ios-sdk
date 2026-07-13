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
  /// A safety setting that affects the safety-blocking behavior. A SafetySetting consists of a harm category and a threshold for that category.
  package struct SafetySetting: Codable, Sendable, Equatable, Hashable {
    /// Required. The harm category to be blocked.
    package var category: Category?
    
    /// Optional. The method for blocking content. If not specified, the default behavior is to use the probability score.
    package var method: Method?
    
    /// Required. The threshold for blocking content. If the harm probability exceeds this threshold, the content will be blocked.
    package var threshold: Threshold?
    
    /// Creates a new `SafetySetting`.
    package init(
      category: Category? = nil,
      method: Method? = nil,
      threshold: Threshold? = nil
    ) {
      self.category = category
      self.method = method
      self.threshold = threshold
    }
    enum CodingKeys: String, CodingKey {
      case category = "category"
      case method = "method"
      case threshold = "threshold"
    }
  }
}