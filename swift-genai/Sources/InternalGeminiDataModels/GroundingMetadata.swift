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
  /// An internal data model for `GroundingMetadata`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGroundingMetadata`
  /// 
  /// Metadata returned to client when grounding is enabled.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GroundingMetadata`
  /// 
  /// Information about the sources that support the content of a response.
  /// 
  /// When grounding is enabled, the model returns citations for claims in the
  /// response. This object contains the retrieved sources.
  package struct GroundingMetadata: Codable, Sendable, Equatable, Hashable {
    /// Optional. Google search entry for the following-up web searches.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Google search entry for the following-up web searches.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. A web search entry point that can be used to display search
    /// results. This field is populated only when the grounding source is Google
    /// Search.
    package let searchEntryPoint: SearchEntryPoint?
    
    /// List of supporting references retrieved from specified grounding source.
    /// 
    /// ### Gemini Developer API
    /// 
    /// List of supporting references retrieved from specified grounding source.
    /// When streaming, this only contains the grounding chunks that have not been
    /// included in the grounding metadata of previous responses.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// A list of supporting references retrieved from the grounding source.
    /// This field is populated when the grounding source is Google Search,
    /// Vertex AI Search, or Google Maps.
    package let groundingChunks: [GroundingChunk]?
    
    /// List of grounding support.
    /// 
    /// ### Gemini Developer API
    /// 
    /// List of grounding support.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. A list of grounding supports that connect the generated
    /// content to the grounding chunks. This field is populated when the grounding
    /// source is Google Search or Vertex AI Search.
    package let groundingSupports: [GroundingSupport]?
    
    /// Metadata related to retrieval in the grounding flow.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Metadata related to retrieval in the grounding flow.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Output only. Metadata related to the retrieval grounding source.
    package let retrievalMetadata: RetrievalMetadata?
    
    /// Web search queries for the following-up web search.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Web search queries for the following-up web search.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The web search queries that were used to generate the content.
    /// This field is populated only when the grounding source is Google Search.
    package let webSearchQueries: [String]?
    
    /// Image search queries used for grounding.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Image search queries used for grounding.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The image search queries that were used to generate the content.
    /// This field is populated only when the grounding source is Google Search
    /// with the Image Search search_type enabled.
    package let imageSearchQueries: [String]?
    
    /// Optional. Resource name of the Google Maps widget context token that can be used
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Resource name of the Google Maps widget context token that can be used
    /// with the PlacesContextElement widget in order to render contextual data.
    /// Only populated in the case that grounding with Google Maps is enabled.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Output only. Deprecated: The Google Maps contextual widget behavior in Grounding with
    /// Google Maps is being deprecated; this field is planned for removal and will
    /// no longer be populated once removed.
    /// 
    /// A token that can be used to render a Google Maps widget with
    /// the contextual data. This field is populated only when the grounding
    /// source is Google Maps.
    package let googleMapsWidgetContextToken: String?
    
    /// Optional. The queries that were executed by the retrieval tools.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The queries that were executed by the retrieval tools.
    /// This field is populated only when the grounding source is a retrieval tool,
    /// such as Vertex AI Search.
    package let retrievalQueries: [String]?
    
    /// Optional. Output only. A list of URIs that can be used to flag a place or review for
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Output only. A list of URIs that can be used to flag a place or review for
    /// inappropriate content. This field is populated only when the grounding
    /// source is Google Maps.
    package let sourceFlaggingUris: [GroundingMetadataSourceFlaggingUri]?
    

    /// Creates a new `GroundingMetadata`.
    ///
    /// - Parameters:
    ///   - searchEntryPoint: Optional. Google search entry for the following-up web searches. (behavior varies by backend). For more details, see ``searchEntryPoint``.
    ///   - groundingChunks: List of supporting references retrieved from specified grounding source. (behavior varies by backend). For more details, see ``groundingChunks``.
    ///   - groundingSupports: List of grounding support. (behavior varies by backend). For more details, see ``groundingSupports``.
    ///   - retrievalMetadata: Metadata related to retrieval in the grounding flow. (behavior varies by backend). For more details, see ``retrievalMetadata``.
    ///   - webSearchQueries: Web search queries for the following-up web search. (behavior varies by backend). For more details, see ``webSearchQueries``.
    ///   - imageSearchQueries: Image search queries used for grounding. (behavior varies by backend). For more details, see ``imageSearchQueries``.
    ///   - googleMapsWidgetContextToken: Optional. Resource name of the Google Maps widget context token that can be used (behavior varies by backend). For more details, see ``googleMapsWidgetContextToken``.
    ///   - retrievalQueries: Optional. The queries that were executed by the retrieval tools. (Gemini Enterprise Agent Platform only). For more details, see ``retrievalQueries``.
    ///   - sourceFlaggingUris: Optional. Output only. A list of URIs that can be used to flag a place or review for (Gemini Enterprise Agent Platform only). For more details, see ``sourceFlaggingUris``.
    package init(
      searchEntryPoint: SearchEntryPoint? = nil,
      groundingChunks: [GroundingChunk]? = nil,
      groundingSupports: [GroundingSupport]? = nil,
      retrievalMetadata: RetrievalMetadata? = nil,
      webSearchQueries: [String]? = nil,
      imageSearchQueries: [String]? = nil,
      googleMapsWidgetContextToken: String? = nil,
      retrievalQueries: [String]? = nil,
      sourceFlaggingUris: [GroundingMetadataSourceFlaggingUri]? = nil
    ) {
      self.searchEntryPoint = searchEntryPoint
      self.groundingChunks = groundingChunks
      self.groundingSupports = groundingSupports
      self.retrievalMetadata = retrievalMetadata
      self.webSearchQueries = webSearchQueries
      self.imageSearchQueries = imageSearchQueries
      self.googleMapsWidgetContextToken = googleMapsWidgetContextToken
      self.retrievalQueries = retrievalQueries
      self.sourceFlaggingUris = sourceFlaggingUris
    }
    enum CodingKeys: String, CodingKey {
      case searchEntryPoint = "searchEntryPoint"
      case groundingChunks = "groundingChunks"
      case groundingSupports = "groundingSupports"
      case retrievalMetadata = "retrievalMetadata"
      case webSearchQueries = "webSearchQueries"
      case imageSearchQueries = "imageSearchQueries"
      case googleMapsWidgetContextToken = "googleMapsWidgetContextToken"
      case retrievalQueries = "retrievalQueries"
      case sourceFlaggingUris = "sourceFlaggingUris"
    }
  }
}