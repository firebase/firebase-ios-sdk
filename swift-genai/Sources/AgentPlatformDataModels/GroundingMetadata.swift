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
  /// Information about the sources that support the content of a response. When grounding is enabled, the model returns citations for claims in the response. This object contains the retrieved sources.
  public struct GroundingMetadata: Codable, Sendable, Equatable, Hashable {
    /// Optional. Output only. Deprecated: The Google Maps contextual widget behavior in Grounding with Google Maps is being deprecated; this field is planned for removal and will no longer be populated once removed. A token that can be used to render a Google Maps widget with the contextual data. This field is populated only when the grounding source is Google Maps.
    @available(*, deprecated)
    public var googleMapsWidgetContextToken: String?
    
    /// A list of supporting references retrieved from the grounding source. This field is populated when the grounding source is Google Search, Vertex AI Search, or Google Maps.
    public var groundingChunks: [GroundingChunk]?
    
    /// Optional. A list of grounding supports that connect the generated content to the grounding chunks. This field is populated when the grounding source is Google Search or Vertex AI Search.
    public var groundingSupports: [GroundingSupport]?
    
    /// Optional. The image search queries that were used to generate the content. This field is populated only when the grounding source is Google Search with the Image Search search_type enabled.
    public var imageSearchQueries: [String]?
    
    /// Optional. Output only. Metadata related to the retrieval grounding source.
    public var retrievalMetadata: RetrievalMetadata?
    
    /// Optional. The queries that were executed by the retrieval tools. This field is populated only when the grounding source is a retrieval tool, such as Vertex AI Search.
    public var retrievalQueries: [String]?
    
    /// Optional. A web search entry point that can be used to display search results. This field is populated only when the grounding source is Google Search.
    public var searchEntryPoint: SearchEntryPoint?
    
    /// Optional. Output only. A list of URIs that can be used to flag a place or review for inappropriate content. This field is populated only when the grounding source is Google Maps.
    public var sourceFlaggingUris: [GroundingMetadataSourceFlaggingUri]?
    
    /// Optional. The web search queries that were used to generate the content. This field is populated only when the grounding source is Google Search.
    public var webSearchQueries: [String]?
    
    /// Creates a new `GroundingMetadata`.
    public init(
      googleMapsWidgetContextToken: String? = nil,
      groundingChunks: [GroundingChunk]? = nil,
      groundingSupports: [GroundingSupport]? = nil,
      imageSearchQueries: [String]? = nil,
      retrievalMetadata: RetrievalMetadata? = nil,
      retrievalQueries: [String]? = nil,
      searchEntryPoint: SearchEntryPoint? = nil,
      sourceFlaggingUris: [GroundingMetadataSourceFlaggingUri]? = nil,
      webSearchQueries: [String]? = nil
    ) {
      self.googleMapsWidgetContextToken = googleMapsWidgetContextToken
      self.groundingChunks = groundingChunks
      self.groundingSupports = groundingSupports
      self.imageSearchQueries = imageSearchQueries
      self.retrievalMetadata = retrievalMetadata
      self.retrievalQueries = retrievalQueries
      self.searchEntryPoint = searchEntryPoint
      self.sourceFlaggingUris = sourceFlaggingUris
      self.webSearchQueries = webSearchQueries
    }
    enum CodingKeys: String, CodingKey {
      case googleMapsWidgetContextToken = "googleMapsWidgetContextToken"
      case groundingChunks = "groundingChunks"
      case groundingSupports = "groundingSupports"
      case imageSearchQueries = "imageSearchQueries"
      case retrievalMetadata = "retrievalMetadata"
      case retrievalQueries = "retrievalQueries"
      case searchEntryPoint = "searchEntryPoint"
      case sourceFlaggingUris = "sourceFlaggingUris"
      case webSearchQueries = "webSearchQueries"
    }
  }
}