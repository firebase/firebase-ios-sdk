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
  /// Identifier for a part within a `GroundingPassage`.
  public struct GroundingPassageId: Codable, Sendable, Equatable, Hashable {
    /// Output only. Index of the part within the `GenerateAnswerRequest`'s `GroundingPassage.content`.
    public var partIndex: Int?
    
    /// Output only. ID of the passage matching the `GenerateAnswerRequest`'s `GroundingPassage.id`.
    public var passageId: String?
    
    /// Creates a new `GroundingPassageId`.
    public init(
      partIndex: Int? = nil,
      passageId: String? = nil
    ) {
      self.partIndex = partIndex
      self.passageId = passageId
    }
    enum CodingKeys: String, CodingKey {
      case partIndex = "partIndex"
      case passageId = "passageId"
    }
  }
}