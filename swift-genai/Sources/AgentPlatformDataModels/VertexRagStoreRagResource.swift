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
  /// The definition of the Rag resource.
  public struct VertexRagStoreRagResource: Codable, Sendable, Equatable, Hashable {
    /// Optional. RagCorpora resource name. Format: `projects/{project}/locations/{location}/ragCorpora/{rag_corpus}`
    public var ragCorpus: String?
    
    /// Optional. rag_file_id. The files should be in the same rag_corpus set in rag_corpus field.
    public var ragFileIds: [String]?
    
    /// Creates a new `VertexRagStoreRagResource`.
    public init(
      ragCorpus: String? = nil,
      ragFileIds: [String]? = nil
    ) {
      self.ragCorpus = ragCorpus
      self.ragFileIds = ragFileIds
    }
    enum CodingKeys: String, CodingKey {
      case ragCorpus = "ragCorpus"
      case ragFileIds = "ragFileIds"
    }
  }
}