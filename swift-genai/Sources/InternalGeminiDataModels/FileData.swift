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
  /// An element in the history the represents an external data file.
  /// 
  /// Variant:
  /// URI-based data. A FileData message contains a URI pointing to data of a specific media type. It is used to represent images, audio, and video stored in Google Cloud Storage.
  package struct FileData: Codable, Sendable, Equatable, Hashable {
    /// Optional. The display name of the file. Used to provide a label or filename to distinguish files. This field is only returned in `PromptMessage` for prompt management. It is used in the Gemini calls only when server side tools (`code_execution`, `google_search`, and `url_context`) are enabled.
    /// 
    /// > Important: `displayName` is only available in the Gemini Enterprise Agent Platform.
    package let displayName: String?
    
    /// Required. The IANA standard MIME type of the source data. Examples: - image/png - image/jpeg
    /// 
    /// Variant:
    /// Required. The IANA standard MIME type of the source data.
    package let mimeType: String?
    
    /// Required. URI.
    /// 
    /// Variant:
    /// Required. The URI of the file in Google Cloud Storage.
    package let fileUri: String?
    
    /// Creates a new `FileData`.
    package init(
      displayName: String? = nil,
      mimeType: String? = nil,
      fileUri: String? = nil
    ) {
      self.displayName = displayName
      self.mimeType = mimeType
      self.fileUri = fileUri
    }
    enum CodingKeys: String, CodingKey {
      case displayName = "displayName"
      case mimeType = "mimeType"
      case fileUri = "fileUri"
    }
  }
}