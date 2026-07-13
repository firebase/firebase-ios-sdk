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

extension GoogleAI {
  /// Safety setting, affecting the safety-blocking behavior. Passing a safety setting for a category changes the allowed probability that content is blocked.
  package struct SafetySetting: Codable, Sendable, Equatable, Hashable {
    /// Required. The category for this setting.
    package var category: Category?
    
    /// Required. Controls the probability threshold at which harm is blocked.
    package var threshold: Threshold?
    
    /// Creates a new `SafetySetting`.
    package init(
      category: Category? = nil,
      threshold: Threshold? = nil
    ) {
      self.category = category
      self.threshold = threshold
    }
    enum CodingKeys: String, CodingKey {
      case category = "category"
      case threshold = "threshold"
    }
  }
}