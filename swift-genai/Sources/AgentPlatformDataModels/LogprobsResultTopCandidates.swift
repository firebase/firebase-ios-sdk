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
  /// A list of the top candidate tokens and their log probabilities at each decoding step. This can be used to see what other tokens the model considered.
  public struct LogprobsResultTopCandidates: Codable, Sendable, Equatable, Hashable {
    /// The list of candidate tokens, sorted by log probability in descending order.
    public var candidates: [LogprobsResultCandidate]?
    
    /// Creates a new `LogprobsResultTopCandidates`.
    public init(
      candidates: [LogprobsResultCandidate]? = nil
    ) {
      self.candidates = candidates
    }
    enum CodingKeys: String, CodingKey {
      case candidates = "candidates"
    }
  }
}