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

/// A URL citation annotation.
package struct URLCitation: Codable, Sendable, Equatable, Hashable {

  /// End of the attributed segment, exclusive.
  package let endIndex: Int?

  /// Start of segment of the response that is attributed to this source.
  ///
  /// Index indicates the start of the segment, measured in bytes.
  package let startIndex: Int?

  /// The title of the URL.
  package let title: String?

  package let type: String?

  /// The URL.
  package let url: String?

  /// Creates a new `URLCitation`.
  ///
  /// - Parameters:
  ///   - endIndex: End of the attributed segment, exclusive.
  ///   - startIndex: Start of segment of the response that is attributed to this source.
  ///   - title: The title of the URL.
  ///   - url: The URL.
  package init(
    endIndex: Int? = nil,
    startIndex: Int? = nil,
    title: String? = nil,
    url: String? = nil
  ) {
    self.endIndex = endIndex
    self.startIndex = startIndex
    self.title = title
    self.type = "url_citation"
    self.url = url
  }
  enum CodingKeys: String, CodingKey {
    case endIndex = "end_index"
    case startIndex = "start_index"
    case title = "title"
    case type = "type"
    case url = "url"
  }
}
