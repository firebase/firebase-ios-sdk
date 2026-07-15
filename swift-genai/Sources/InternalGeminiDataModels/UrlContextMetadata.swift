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
  /// An internal data model for `UrlContextMetadata`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaUrlContextMetadata`
  /// 
  /// Metadata related to url context retrieval tool.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1UrlContextMetadata`
  /// 
  /// Metadata returned when the model uses the `url_context` tool
  /// to get information from a user-provided URL.
  package struct UrlContextMetadata: Codable, Sendable, Equatable, Hashable {
    /// List of url context.
    /// 
    /// ### Gemini Developer API
    /// 
    /// List of url context.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A list of URL metadata, with one entry for each URL
    /// retrieved by the tool.
    package let urlMetadata: [UrlMetadata]?
    

    /// Creates a new `UrlContextMetadata`.
    ///
    /// - Parameters:
    ///   - urlMetadata: List of url context. (behavior varies by backend). For more details, see ``urlMetadata``.
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