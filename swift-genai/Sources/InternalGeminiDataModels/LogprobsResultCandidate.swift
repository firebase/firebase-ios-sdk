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
  /// An internal data model for `LogprobsResultCandidate`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaLogprobsResultCandidate`
  /// 
  /// Candidate for the logprobs token and score.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1LogprobsResultCandidate`
  /// 
  /// A single token and its associated log probability.
  package struct LogprobsResultCandidate: Codable, Sendable, Equatable, Hashable {
    /// The candidate’s token string value.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The candidate’s token string value.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The token's string representation.
    package let token: String?
    
    /// The candidate’s token id value.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The candidate’s token id value.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The token's numerical ID. While the `token` field provides
    /// the string representation of the token, the `token_id` is the numerical
    /// representation that the model uses internally. This can be useful for
    /// developers who want to build custom logic based on the model's
    /// vocabulary.
    package let tokenId: Int?
    
    /// The candidate's log probability.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The candidate's log probability.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The log probability of this token. A higher value indicates
    /// that the model was more confident in this token. The log probability can
    /// be used to assess the relative likelihood of different tokens and to
    /// identify when the model is uncertain.
    package let logProbability: Double?
    

    /// Creates a new `LogprobsResultCandidate`.
    ///
    /// - Parameters:
    ///   - token: The candidate’s token string value. (behavior varies by backend). For more details, see ``token``.
    ///   - tokenId: The candidate’s token id value. (behavior varies by backend). For more details, see ``tokenId``.
    ///   - logProbability: The candidate's log probability. (behavior varies by backend). For more details, see ``logProbability``.
    package init(
      token: String? = nil,
      tokenId: Int? = nil,
      logProbability: Double? = nil
    ) {
      self.token = token
      self.tokenId = tokenId
      self.logProbability = logProbability
    }
    enum CodingKeys: String, CodingKey {
      case token = "token"
      case tokenId = "tokenId"
      case logProbability = "logProbability"
    }
  }
}