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

package import GeminiSharedDataModels

/// A file citation annotation.
package struct FileCitation: Codable, Sendable, Equatable, Hashable {

  /// User provided metadata about the retrieved context.
  package let customMetadata: [String: JSONValue]?

  /// The URI of the file.
  package let documentUri: String?

  /// End of the attributed segment, exclusive.
  package let endIndex: Int?

  /// The name of the file.
  package let fileName: String?

  /// Media ID in-case of image citations, if applicable.
  package let mediaId: String?

  /// Page number of the cited document, if applicable.
  package let pageNumber: Int?

  /// Source attributed for a portion of the text.
  package let source: String?

  /// Start of segment of the response that is attributed to this source.
  ///
  /// Index indicates the start of the segment, measured in bytes.
  package let startIndex: Int?

  package let type: String?

  /// Creates a new `FileCitation`.
  ///
  /// - Parameters:
  ///   - customMetadata: User provided metadata about the retrieved context.
  ///   - documentUri: The URI of the file.
  ///   - endIndex: End of the attributed segment, exclusive.
  ///   - fileName: The name of the file.
  ///   - mediaId: Media ID in-case of image citations, if applicable.
  ///   - pageNumber: Page number of the cited document, if applicable.
  ///   - source: Source attributed for a portion of the text.
  ///   - startIndex: Start of segment of the response that is attributed to this source.
  package init(
    customMetadata: [String: JSONValue]? = nil,
    documentUri: String? = nil,
    endIndex: Int? = nil,
    fileName: String? = nil,
    mediaId: String? = nil,
    pageNumber: Int? = nil,
    source: String? = nil,
    startIndex: Int? = nil
  ) {
    self.customMetadata = customMetadata
    self.documentUri = documentUri
    self.endIndex = endIndex
    self.fileName = fileName
    self.mediaId = mediaId
    self.pageNumber = pageNumber
    self.source = source
    self.startIndex = startIndex
    self.type = "file_citation"
  }
  enum CodingKeys: String, CodingKey {
    case customMetadata = "custom_metadata"
    case documentUri = "document_uri"
    case endIndex = "end_index"
    case fileName = "file_name"
    case mediaId = "media_id"
    case pageNumber = "page_number"
    case source = "source"
    case startIndex = "start_index"
    case type = "type"
  }
}
