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
  /// Context of the a single url retrieval.
  package struct UrlMetadata: Codable, Sendable, Equatable, Hashable {
    /// Retrieved url by the tool.
    package var retrievedUrl: String?
    
    /// Status of the url retrieval.
    package var urlRetrievalStatus: UrlRetrievalStatus?
    
    /// Creates a new `UrlMetadata`.
    package init(
      retrievedUrl: String? = nil,
      urlRetrievalStatus: UrlRetrievalStatus? = nil
    ) {
      self.retrievedUrl = retrievedUrl
      self.urlRetrievalStatus = urlRetrievalStatus
    }
    enum CodingKeys: String, CodingKey {
      case retrievedUrl = "retrievedUrl"
      case urlRetrievalStatus = "urlRetrievalStatus"
    }
  }
}