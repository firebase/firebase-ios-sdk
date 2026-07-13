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
  /// The FileSearch tool that retrieves knowledge from Semantic Retrieval corpora. Files are imported to Semantic Retrieval corpora using the ImportFile API.
  package struct FileSearch: Codable, Sendable, Equatable, Hashable {
    /// Required. The names of the file_search_stores to retrieve from. Example: `fileSearchStores/my-file-search-store-123`
    package var fileSearchStoreNames: [String]?
    
    /// Optional. Metadata filter to apply to the semantic retrieval documents and chunks.
    package var metadataFilter: String?
    
    /// Optional. The number of semantic retrieval chunks to retrieve.
    package var topK: Int?
    
    /// Creates a new `FileSearch`.
    package init(
      fileSearchStoreNames: [String]? = nil,
      metadataFilter: String? = nil,
      topK: Int? = nil
    ) {
      self.fileSearchStoreNames = fileSearchStoreNames
      self.metadataFilter = metadataFilter
      self.topK = topK
    }
    enum CodingKeys: String, CodingKey {
      case fileSearchStoreNames = "fileSearchStoreNames"
      case metadataFilter = "metadataFilter"
      case topK = "topK"
    }
  }
}