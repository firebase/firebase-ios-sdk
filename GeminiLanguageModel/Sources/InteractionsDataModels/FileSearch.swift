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

/// A tool that can be used by the model to search files.
package struct FileSearch: Codable, Sendable, Equatable, Hashable {

  /// The file search store names to search.
  package let fileSearchStoreNames: [String]?

  /// Metadata filter to apply to the semantic retrieval documents and chunks.
  package let metadataFilter: String?

  /// The number of semantic retrieval chunks to retrieve.
  package let topK: Int?

  package let type: String?

  /// Creates a new `FileSearch`.
  ///
  /// - Parameters:
  ///   - fileSearchStoreNames: The file search store names to search.
  ///   - metadataFilter: Metadata filter to apply to the semantic retrieval documents and chunks.
  ///   - topK: The number of semantic retrieval chunks to retrieve.
  package init(
    fileSearchStoreNames: [String]? = nil,
    metadataFilter: String? = nil,
    topK: Int? = nil
  ) {
    self.fileSearchStoreNames = fileSearchStoreNames
    self.metadataFilter = metadataFilter
    self.topK = topK
    self.type = "file_search"
  }
  enum CodingKeys: String, CodingKey {
    case fileSearchStoreNames = "file_search_store_names"
    case metadataFilter = "metadata_filter"
    case topK = "top_k"
    case type = "type"
  }
}
