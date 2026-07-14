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
  /// Metadata related to retrieval in the grounding flow.
  public struct RetrievalMetadata: Codable, Sendable, Equatable, Hashable {
    /// Optional. Score indicating how likely information from google search could help answer the prompt. The score is in the range [0, 1], where 0 is the least likely and 1 is the most likely. This score is only populated when google search grounding and dynamic retrieval is enabled. It will be compared to the threshold to determine whether to trigger google search.
    public var googleSearchDynamicRetrievalScore: Double?
    
    /// Creates a new `RetrievalMetadata`.
    public init(
      googleSearchDynamicRetrievalScore: Double? = nil
    ) {
      self.googleSearchDynamicRetrievalScore = googleSearchDynamicRetrievalScore
    }
    enum CodingKeys: String, CodingKey {
      case googleSearchDynamicRetrievalScore = "googleSearchDynamicRetrievalScore"
    }
  }
}