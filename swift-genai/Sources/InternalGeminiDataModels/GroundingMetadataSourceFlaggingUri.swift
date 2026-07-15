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
  /// An internal data model for `GroundingMetadataSourceFlaggingUri`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GroundingMetadataSourceFlaggingUri`
  /// 
  /// A URI that can be used to flag a place or review for inappropriate
  /// content. This is populated only when the grounding source is Google Maps.
  package struct GroundingMetadataSourceFlaggingUri: Codable, Sendable, Equatable, Hashable {
    /// The ID of the place or review.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The ID of the place or review.
    package let sourceId: String?
    
    /// The URI that can be used to flag the content.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The URI that can be used to flag the content.
    package let flagContentUri: String?
    

    /// Creates a new `GroundingMetadataSourceFlaggingUri`.
    ///
    /// - Parameters:
    ///   - sourceId: The ID of the place or review. (Gemini Enterprise Agent Platform only). For more details, see ``sourceId``.
    ///   - flagContentUri: The URI that can be used to flag the content. (Gemini Enterprise Agent Platform only). For more details, see ``flagContentUri``.
    package init(
      sourceId: String? = nil,
      flagContentUri: String? = nil
    ) {
      self.sourceId = sourceId
      self.flagContentUri = flagContentUri
    }
    enum CodingKeys: String, CodingKey {
      case sourceId = "sourceId"
      case flagContentUri = "flagContentUri"
    }
  }
}