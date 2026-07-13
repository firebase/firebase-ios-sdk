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
  /// A single token and its associated log probability.
  package struct LogprobsResultCandidate: Codable, Sendable, Equatable, Hashable {
    /// The log probability of this token. A higher value indicates that the model was more confident in this token. The log probability can be used to assess the relative likelihood of different tokens and to identify when the model is uncertain.
    package var logProbability: Double?
    
    /// The token's string representation.
    package var token: String?
    
    /// The token's numerical ID. While the `token` field provides the string representation of the token, the `token_id` is the numerical representation that the model uses internally. This can be useful for developers who want to build custom logic based on the model's vocabulary.
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