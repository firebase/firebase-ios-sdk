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
  /// Raw media bytes for function response. Text should not be sent as raw bytes, use the 'FunctionResponse.response' field.
  package struct FunctionResponseBlob: Codable, Sendable, Equatable, Hashable {
    /// Raw bytes for media formats.
    package var data: String?
    
    /// The IANA standard MIME type of the source data. Examples: - image/png - image/jpeg If an unsupported MIME type is provided, an error will be returned. For a complete list of supported types, see [Supported file formats](https://ai.google.dev/gemini-api/docs/prompting_with_media#supported_file_formats).
    package var mimeType: String?
    
    /// Creates a new `FunctionResponseBlob`.
    package init(
      data: String? = nil,
      mimeType: String? = nil
    ) {
      self.data = data
      self.mimeType = mimeType
    }
    enum CodingKeys: String, CodingKey {
      case data = "data"
      case mimeType = "mimeType"
    }
  }
}