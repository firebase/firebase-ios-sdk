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
  /// Tool to retrieve public web data for grounding, powered by Google.
  package struct GoogleSearchRetrieval: Codable, Sendable, Equatable, Hashable {
    /// Specifies the dynamic retrieval configuration for the given source.
    package var dynamicRetrievalConfig: DynamicRetrievalConfig?
    
    /// Creates a new `GoogleSearchRetrieval`.
    package init(
      dynamicRetrievalConfig: DynamicRetrievalConfig? = nil
    ) {
      self.dynamicRetrievalConfig = dynamicRetrievalConfig
    }
    enum CodingKeys: String, CodingKey {
      case dynamicRetrievalConfig = "dynamicRetrievalConfig"
    }
  }
}