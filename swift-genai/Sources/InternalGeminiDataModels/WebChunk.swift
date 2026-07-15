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
  /// An internal data model for `WebChunk`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGroundingChunkWeb`
  /// 
  /// Chunk from the web.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GroundingChunkWeb`
  /// 
  /// A `Web` chunk is a piece of evidence that comes from a web page. It
  /// contains the URI of the web page, the title of the page, and the domain of
  /// the page. This is used to provide the user with a link to the source of
  /// the information.
  package struct WebChunk: Codable, Sendable, Equatable, Hashable {
    /// Output only. URI reference of the chunk.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. URI reference of the chunk.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The URI of the web page that contains the evidence.
    package let uri: String?
    
    /// Output only. Title of the chunk.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Title of the chunk.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The title of the web page that contains the evidence.
    package let title: String?
    
    /// The domain of the web page that contains the evidence. This
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The domain of the web page that contains the evidence. This
    /// can be used to filter out low-quality sources.
    package let domain: String?
    

    /// Creates a new `WebChunk`.
    ///
    /// - Parameters:
    ///   - uri: Output only. URI reference of the chunk. (behavior varies by backend). For more details, see ``uri``.
    ///   - title: Output only. Title of the chunk. (behavior varies by backend). For more details, see ``title``.
    ///   - domain: The domain of the web page that contains the evidence. This (Gemini Enterprise Agent Platform only). For more details, see ``domain``.
    package init(
      uri: String? = nil,
      title: String? = nil,
      domain: String? = nil
    ) {
      self.uri = uri
      self.title = title
      self.domain = domain
    }
    enum CodingKeys: String, CodingKey {
      case uri = "uri"
      case title = "title"
      case domain = "domain"
    }
  }
}