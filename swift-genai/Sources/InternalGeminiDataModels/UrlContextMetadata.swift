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
  /// Metadata related to url context retrieval tool.
  /// 
  /// Variant:
  /// Metadata returned when the model uses the `url_context` tool to get information from a user-provided URL.
  package struct UrlContextMetadata: Codable, Sendable, Equatable, Hashable {
    /// List of url context.
    /// 
    /// Variant:
    /// Output only. A list of URL metadata, with one entry for each URL retrieved by the tool.
    package let urlMetadata: [UrlMetadata]?
    
    /// Creates a new `UrlContextMetadata`.
    package init(
      urlMetadata: [UrlMetadata]? = nil
    ) {
      self.urlMetadata = urlMetadata
    }
    enum CodingKeys: String, CodingKey {
      case urlMetadata = "urlMetadata"
    }
  }
}