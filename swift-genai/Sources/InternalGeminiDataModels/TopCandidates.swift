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
  /// An internal data model for `TopCandidates`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaLogprobsResultTopCandidates`
  /// 
  /// Candidates with top log probabilities at each decoding step.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1LogprobsResultTopCandidates`
  /// 
  /// A list of the top candidate tokens and their log probabilities
  /// at each decoding step. This can be used to see what other tokens the model
  /// considered.
  package struct TopCandidates: Codable, Sendable, Equatable, Hashable {
    /// Sorted by log probability in descending order.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Sorted by log probability in descending order.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The list of candidate tokens, sorted by log probability in
    /// descending order.
    package let candidates: [LogprobsResultCandidate]?
    

    /// Creates a new `TopCandidates`.
    ///
    /// - Parameters:
    ///   - candidates: Sorted by log probability in descending order. (behavior varies by backend). For more details, see ``candidates``.
    package init(
      candidates: [LogprobsResultCandidate]? = nil
    ) {
      self.candidates = candidates
    }
    enum CodingKeys: String, CodingKey {
      case candidates = "candidates"
    }
  }
}