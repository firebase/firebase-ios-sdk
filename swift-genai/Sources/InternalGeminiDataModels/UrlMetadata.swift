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
  /// An internal data model for `UrlMetadata`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaUrlMetadata`
  /// 
  /// Context of the a single url retrieval.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1UrlMetadata`
  /// 
  /// The metadata for a single URL retrieval.
  package struct UrlMetadata: Codable, Sendable, Equatable, Hashable {
    /// Retrieved url by the tool.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Retrieved url by the tool.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The URL retrieved by the tool.
    package let retrievedUrl: String?
    
    /// Status of the url retrieval.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Status of the url retrieval.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The status of the URL retrieval.
    package let urlRetrievalStatus: UrlRetrievalStatus?
    

    /// Creates a new `UrlMetadata`.
    ///
    /// - Parameters:
    ///   - retrievedUrl: Retrieved url by the tool. (behavior varies by backend). For more details, see ``retrievedUrl``.
    ///   - urlRetrievalStatus: Status of the url retrieval. (behavior varies by backend). For more details, see ``urlRetrievalStatus``.
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