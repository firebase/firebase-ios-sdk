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
  /// Candidate for the logprobs token and score.
  package struct LogprobsResultCandidate: Codable, Sendable, Equatable, Hashable {
    /// The candidate's log probability.
    package var logProbability: Double?
    
    /// The candidate’s token string value.
    package var token: String?
    
    /// The candidate’s token id value.
    package var tokenId: Int?
    
    /// Creates a new `LogprobsResultCandidate`.
    package init(
      logProbability: Double? = nil,
      token: String? = nil,
      tokenId: Int? = nil
    ) {
      self.logProbability = logProbability
      self.token = token
      self.tokenId = tokenId
    }
    enum CodingKeys: String, CodingKey {
      case logProbability = "logProbability"
      case token = "token"
      case tokenId = "tokenId"
    }
  }
}