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
  /// Metadata returned to client when grounding is enabled.
  /// 
  /// Variant:
  /// Information about the sources that support the content of a response. When grounding is enabled, the model returns citations for claims in the response. This object contains the retrieved sources.
  package struct GroundingMetadata: Codable, Sendable, Equatable, Hashable {
    /// Metadata related to retrieval in the grounding flow.
    /// 
    /// Variant:
    /// Optional. Output only. Metadata related to the retrieval grounding source.
    package let retrievalMetadata: RetrievalMetadata?
    
    /// List of grounding support.
    /// 
    /// Variant:
    /// Optional. A list of grounding supports that connect the generated content to the grounding chunks. This field is populated when the grounding source is Google Search or Vertex AI Search.
    package let groundingSupports: [GroundingSupport]?
    
    /// Optional. Resource name of the Google Maps widget context token that can be used with the PlacesContextElement widget in order to render contextual data. Only populated in the case that grounding with Google Maps is enabled.
    /// 
    /// Variant:
    /// Optional. Output only. Deprecated: The Google Maps contextual widget behavior in Grounding with Google Maps is being deprecated; this field is planned for removal and will no longer be populated once removed. A token that can be used to render a Google Maps widget with the contextual data. This field is populated only when the grounding source is Google Maps.
    package let googleMapsWidgetContextToken: String?
    
    /// List of supporting references retrieved from specified grounding source. When streaming, this only contains the grounding chunks that have not been included in the grounding metadata of previous responses.
    /// 
    /// Variant:
    /// A list of supporting references retrieved from the grounding source. This field is populated when the grounding source is Google Search, Vertex AI Search, or Google Maps.
    package let groundingChunks: [GroundingChunk]?
    
    /// Optional. Google search entry for the following-up web searches.
    /// 
    /// Variant:
    /// Optional. A web search entry point that can be used to display search results. This field is populated only when the grounding source is Google Search.
    package let searchEntryPoint: SearchEntryPoint?
    
    /// Optional. Output only. A list of URIs that can be used to flag a place or review for inappropriate content. This field is populated only when the grounding source is Google Maps.
    /// 
    /// > Important: `sourceFlaggingUris` is only available in the Gemini Enterprise Agent Platform.
    package let sourceFlaggingUris: [GroundingMetadataSourceFlaggingUri]?
    
    /// Optional. The queries that were executed by the retrieval tools. This field is populated only when the grounding source is a retrieval tool, such as Vertex AI Search.
    /// 
    /// > Important: `retrievalQueries` is only available in the Gemini Enterprise Agent Platform.
    package let retrievalQueries: [String]?
    
    /// Image search queries used for grounding.
    /// 
    /// Variant:
    /// Optional. The image search queries that were used to generate the content. This field is populated only when the grounding source is Google Search with the Image Search search_type enabled.
    package let imageSearchQueries: [String]?
    
    /// Web search queries for the following-up web search.
    /// 
    /// Variant:
    /// Optional. The web search queries that were used to generate the content. This field is populated only when the grounding source is Google Search.
    package let webSearchQueries: [String]?
    
    /// Creates a new `GroundingMetadata`.
    package init(
      retrievalMetadata: RetrievalMetadata? = nil,
      groundingSupports: [GroundingSupport]? = nil,
      googleMapsWidgetContextToken: String? = nil,
      groundingChunks: [GroundingChunk]? = nil,
      searchEntryPoint: SearchEntryPoint? = nil,
      sourceFlaggingUris: [GroundingMetadataSourceFlaggingUri]? = nil,
      retrievalQueries: [String]? = nil,
      imageSearchQueries: [String]? = nil,
      webSearchQueries: [String]? = nil
    ) {
      self.retrievalMetadata = retrievalMetadata
      self.groundingSupports = groundingSupports
      self.googleMapsWidgetContextToken = googleMapsWidgetContextToken
      self.groundingChunks = groundingChunks
      self.searchEntryPoint = searchEntryPoint
      self.sourceFlaggingUris = sourceFlaggingUris
      self.retrievalQueries = retrievalQueries
      self.imageSearchQueries = imageSearchQueries
      self.webSearchQueries = webSearchQueries
    }
    enum CodingKeys: String, CodingKey {
      case retrievalMetadata = "retrievalMetadata"
      case groundingSupports = "groundingSupports"
      case googleMapsWidgetContextToken = "googleMapsWidgetContextToken"
      case groundingChunks = "groundingChunks"
      case searchEntryPoint = "searchEntryPoint"
      case sourceFlaggingUris = "sourceFlaggingUris"
      case retrievalQueries = "retrievalQueries"
      case imageSearchQueries = "imageSearchQueries"
      case webSearchQueries = "webSearchQueries"
    }
  }
}