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

/// Configuration for text output format.
package struct TextResponseFormat: Codable, Sendable, Equatable, Hashable {

  /// The MIME type of the text output.
  package let mimeType: MimeType?

  /// The JSON schema that the output should conform to. Only applicable when
  /// mime_type is application/json.
  package let schema: [String: JSONValue]?

  package let type: String?

  /// Creates a new `TextResponseFormat`.
  ///
  /// - Parameters:
  ///   - mimeType: The MIME type of the text output.
  ///   - schema: The JSON schema that the output should conform to. Only applicable when
  package init(
    mimeType: MimeType? = nil,
    schema: [String: JSONValue]? = nil
  ) {
    self.mimeType = mimeType
    self.schema = schema
    self.type = "text"
  }
  enum CodingKeys: String, CodingKey {
    case mimeType = "mime_type"
    case schema = "schema"
    case type = "type"
  }
}
