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
  /// Metadata returned to client when grounding is enabled.
  package struct GroundingMetadata: Codable, Sendable, Equatable, Hashable {
    /// Optional. Resource name of the Google Maps widget context token that can be used with the PlacesContextElement widget in order to render contextual data. Only populated in the case that grounding with Google Maps is enabled.
    package var googleMapsWidgetContextToken: String?
    
    /// List of supporting references retrieved from specified grounding source. When streaming, this only contains the grounding chunks that have not been included in the grounding metadata of previous responses.
    package var groundingChunks: [GroundingChunk]?
    
    /// List of grounding support.
    package var groundingSupports: [GoogleAiGenerativelanguageV1betaGroundingSupport]?
    
    /// Image search queries used for grounding.
    package var imageSearchQueries: [String]?
    
    /// Metadata related to retrieval in the grounding flow.
    package var retrievalMetadata: RetrievalMetadata?
    
    /// Optional. Google search entry for the following-up web searches.
    package var searchEntryPoint: SearchEntryPoint?
    
    /// Web search queries for the following-up web search.
    package var webSearchQueries: [String]?
    
    /// Creates a new `GroundingMetadata`.
    package init(
      googleMapsWidgetContextToken: String? = nil,
      groundingChunks: [GroundingChunk]? = nil,
      groundingSupports: [GoogleAiGenerativelanguageV1betaGroundingSupport]? = nil,
      imageSearchQueries: [String]? = nil,
      retrievalMetadata: RetrievalMetadata? = nil,
      searchEntryPoint: SearchEntryPoint? = nil,
      webSearchQueries: [String]? = nil
    ) {
      self.googleMapsWidgetContextToken = googleMapsWidgetContextToken
      self.groundingChunks = groundingChunks
      self.groundingSupports = groundingSupports
      self.imageSearchQueries = imageSearchQueries
      self.retrievalMetadata = retrievalMetadata
      self.searchEntryPoint = searchEntryPoint
      self.webSearchQueries = webSearchQueries
    }
    enum CodingKeys: String, CodingKey {
      case googleMapsWidgetContextToken = "googleMapsWidgetContextToken"
      case groundingChunks = "groundingChunks"
      case groundingSupports = "groundingSupports"
      case imageSearchQueries = "imageSearchQueries"
      case retrievalMetadata = "retrievalMetadata"
      case searchEntryPoint = "searchEntryPoint"
      case webSearchQueries = "webSearchQueries"
    }
  }
}