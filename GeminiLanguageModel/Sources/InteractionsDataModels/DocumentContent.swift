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

package import Foundation

/// A document content block.
package struct DocumentContent: Codable, Sendable, Equatable, Hashable {

  /// The document content.
  package let data: Data?

  /// The mime type of the document.
  package let mimeType: MimeType?

  package let type: String?

  /// The URI of the document.
  package let uri: String?

  /// Creates a new `DocumentContent`.
  ///
  /// - Parameters:
  ///   - data: The document content.
  ///   - mimeType: The mime type of the document.
  ///   - uri: The URI of the document.
  package init(
    data: Data? = nil,
    mimeType: MimeType? = nil,
    uri: String? = nil
  ) {
    self.data = data
    self.mimeType = mimeType
    self.type = "document"
    self.uri = uri
  }
  enum CodingKeys: String, CodingKey {
    case data = "data"
    case mimeType = "mime_type"
    case type = "type"
    case uri = "uri"
  }
}
