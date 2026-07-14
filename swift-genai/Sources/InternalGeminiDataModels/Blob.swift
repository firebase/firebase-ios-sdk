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


extension GeminiDataModels {
  /// Raw media bytes. Text should not be sent as raw bytes, use the 'text' field.
  /// 
  /// Variant:
  /// An element in the history the represents raw binary data.
  package struct Blob: Codable, Sendable, Equatable, Hashable {
    /// Raw bytes for media formats.
    /// 
    /// Variant:
    /// Required. Raw bytes for media formats.
    package let data: String?
    
    /// The IANA standard MIME type of the source data. Examples of supported types: - Images: image/png, image/jpeg, image/jpg, image/webp, image/heic, image/heif, image/gif, image/avif - Audio: audio/*, video/audio/s16le, video/audio/wav - Video: video/* - Text: text/plain, text/html, text/css, text/javascript, text/x-typescript, text/csv, text/markdown, text/x-python, text/xml, text/rtf, video/text/timestamp - Applications: application/x-javascript, application/x-typescript, application/x-python-code, application/json, application/x-ipynb+json, application/rtf, application/pdf For additional context, see [Supported file formats](https://ai.google.dev/gemini-api/docs/file-input-methods#supported-content-types). //
    /// 
    /// Variant:
    /// Required. The IANA standard MIME type of the source data. Examples: - image/png - image/jpeg
    package let mimeType: String?
    
    /// Creates a new `Blob`.
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