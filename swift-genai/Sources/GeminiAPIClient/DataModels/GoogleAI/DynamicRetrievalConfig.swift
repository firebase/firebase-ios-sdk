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
  /// Describes the options to customize dynamic retrieval.
  package struct DynamicRetrievalConfig: Codable, Sendable, Equatable, Hashable {
    /// The threshold to be used in dynamic retrieval. If not set, a system default value is used.
    package var dynamicThreshold: Double?
    
    /// The mode of the predictor to be used in dynamic retrieval.
    package var mode: Mode?
    
    /// Creates a new `DynamicRetrievalConfig`.
    package init(
      dynamicThreshold: Double? = nil,
      mode: Mode? = nil
    ) {
      self.dynamicThreshold = dynamicThreshold
      self.mode = mode
    }
    enum CodingKeys: String, CodingKey {
      case dynamicThreshold = "dynamicThreshold"
      case mode = "mode"
    }
  }
}