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
  /// Safety setting, affecting the safety-blocking behavior. Passing a safety setting for a category changes the allowed probability that content is blocked.
  /// 
  /// Variant:
  /// A safety setting that affects the safety-blocking behavior. A SafetySetting consists of a harm category and a threshold for that category.
  package struct SafetySetting: Codable, Sendable, Equatable, Hashable {
    /// Optional. The method for blocking content. If not specified, the default behavior is to use the probability score.
    /// 
    /// > Important: `method` is only available in the Gemini Enterprise Agent Platform.
    package let method: Method?
    
    /// Required. Controls the probability threshold at which harm is blocked.
    /// 
    /// Variant:
    /// Required. The threshold for blocking content. If the harm probability exceeds this threshold, the content will be blocked.
    package let threshold: Threshold?
    
    /// Required. The category for this setting.
    /// 
    /// Variant:
    /// Required. The harm category to be blocked.
    package let category: Category?
    
    /// Creates a new `SafetySetting`.
    package init(
      method: Method? = nil,
      threshold: Threshold? = nil,
      category: Category? = nil
    ) {
      self.method = method
      self.threshold = threshold
      self.category = category
    }
    enum CodingKeys: String, CodingKey {
      case method = "method"
      case threshold = "threshold"
      case category = "category"
    }
  }
}