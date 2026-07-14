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
  /// Represents where the chunk starts and ends in the document.
  public struct RagChunkPageSpan: Codable, Sendable, Equatable, Hashable {
    /// Page where chunk starts in the document. Inclusive. 1-indexed.
    public var firstPage: Int?
    
    /// Page where chunk ends in the document. Inclusive. 1-indexed.
    public var lastPage: Int?
    
    /// Creates a new `RagChunkPageSpan`.
    public init(
      firstPage: Int? = nil,
      lastPage: Int? = nil
    ) {
      self.firstPage = firstPage
      self.lastPage = lastPage
    }
    enum CodingKeys: String, CodingKey {
      case firstPage = "firstPage"
      case lastPage = "lastPage"
    }
  }
}