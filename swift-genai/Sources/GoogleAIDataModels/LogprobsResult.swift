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
  /// Logprobs Result
  package struct LogprobsResult: Codable, Sendable, Equatable, Hashable {
    /// Length = total number of decoding steps. The chosen candidates may or may not be in top_candidates.
    package var chosenCandidates: [LogprobsResultCandidate]?
    
    /// Sum of log probabilities for all tokens.
    package var logProbabilitySum: Double?
    
    /// Length = total number of decoding steps.
    package var topCandidates: [TopCandidates]?
    
    /// Creates a new `LogprobsResult`.
    package init(
      chosenCandidates: [LogprobsResultCandidate]? = nil,
      logProbabilitySum: Double? = nil,
      topCandidates: [TopCandidates]? = nil
    ) {
      self.chosenCandidates = chosenCandidates
      self.logProbabilitySum = logProbabilitySum
      self.topCandidates = topCandidates
    }
    enum CodingKeys: String, CodingKey {
      case chosenCandidates = "chosenCandidates"
      case logProbabilitySum = "logProbabilitySum"
      case topCandidates = "topCandidates"
    }
  }
}