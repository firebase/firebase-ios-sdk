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
  /// An internal data model for `FileData`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `FileData`
  /// 
  /// An element in the history the represents an external data file.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1FileData`
  /// 
  /// URI-based data.
  /// 
  /// A FileData message contains a URI
  /// pointing to data of a specific media type. It is used to represent images,
  /// audio, and video stored in Google Cloud Storage.
  package struct FileData: Codable, Sendable, Equatable, Hashable {
    /// Required. The IANA standard MIME type of the source data.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The IANA standard MIME type of the source data.
    /// Examples:
    ///   - image/png
    ///   - image/jpeg
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The IANA standard MIME type of the source data.
    package let mimeType: String
    
    /// Required. URI.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. URI.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The URI of the file in Google Cloud Storage.
    package let fileUri: String
    
    /// Optional. The display name of the file. Used to provide a label or filename
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The display name of the file. Used to provide a label or filename
    /// to distinguish files.
    /// 
    /// This field is only returned in `PromptMessage` for prompt management. It is
    /// used in the Gemini calls only when server side tools (`code_execution`,
    /// `google_search`, and `url_context`) are enabled.
    package let displayName: String?
    

    /// Creates a new `FileData`.
    ///
    /// - Parameters:
    ///   - mimeType: Required. The IANA standard MIME type of the source data. (behavior varies by backend). For more details, see ``mimeType``.
    ///   - fileUri: Required. URI. (behavior varies by backend). For more details, see ``fileUri``.
    ///   - displayName: Optional. The display name of the file. Used to provide a label or filename (Gemini Enterprise Agent Platform only). For more details, see ``displayName``.
    package init(
      mimeType: String,
      fileUri: String,
      displayName: String? = nil
    ) {
      self.mimeType = mimeType
      self.fileUri = fileUri
      self.displayName = displayName
    }
    enum CodingKeys: String, CodingKey {
      case mimeType = "mimeType"
      case fileUri = "fileUri"
      case displayName = "displayName"
    }
  }
}