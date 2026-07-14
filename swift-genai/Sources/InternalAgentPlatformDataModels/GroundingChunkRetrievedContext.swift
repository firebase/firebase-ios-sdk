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
  /// Context retrieved from a data source to ground the model's response. This is used when a retrieval tool fetches information from a user-provided corpus or a public dataset.
  public struct GroundingChunkRetrievedContext: Codable, Sendable, Equatable, Hashable {
    /// Output only. The full resource name of the referenced Vertex AI Search document. This is used to identify the specific document that was retrieved. The format is `projects/{project}/locations/{location}/collections/{collection}/dataStores/{data_store}/branches/{branch}/documents/{document}`.
    public var documentName: String?
    
    /// Additional context for a Retrieval-Augmented Generation (RAG) retrieval result. This is populated only when the RAG retrieval tool is used.
    public var ragChunk: RagChunk?
    
    /// The content of the retrieved data source.
    public var text: String?
    
    /// The title of the retrieved data source.
    public var title: String?
    
    /// The URI of the retrieved data source.
    public var uri: String?
    
    /// Creates a new `GroundingChunkRetrievedContext`.
    public init(
      documentName: String? = nil,
      ragChunk: RagChunk? = nil,
      text: String? = nil,
      title: String? = nil,
      uri: String? = nil
    ) {
      self.documentName = documentName
      self.ragChunk = ragChunk
      self.text = text
      self.title = title
      self.uri = uri
    }
    enum CodingKeys: String, CodingKey {
      case documentName = "documentName"
      case ragChunk = "ragChunk"
      case text = "text"
      case title = "title"
      case uri = "uri"
    }
  }
}