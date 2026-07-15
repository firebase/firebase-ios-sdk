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
  /// An internal data model for `FunctionResponseFileData`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1FunctionResponseFileData`
  /// 
  /// URI based data for function response.
  package struct FunctionResponseFileData: Codable, Sendable, Equatable, Hashable {
    /// Required. The IANA standard MIME type of the source data.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The IANA standard MIME type of the source data.
    package let mimeType: String
    
    /// Required. URI.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. URI.
    package let fileUri: String
    
    /// Optional. Display name of the file data.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Display name of the file data.
    /// 
    /// Used to provide a label or filename to distinguish file datas.
    /// 
    /// This field is only returned in PromptMessage for prompt management.
    /// It is currently used in the Gemini GenerateContent calls only when server
    /// side tools (code_execution, google_search, and url_context) are enabled.
    package let displayName: String?
    

    /// Creates a new `FunctionResponseFileData`.
    ///
    /// - Parameters:
    ///   - mimeType: Required. The IANA standard MIME type of the source data. (Gemini Enterprise Agent Platform only). For more details, see ``mimeType``.
    ///   - fileUri: Required. URI. (Gemini Enterprise Agent Platform only). For more details, see ``fileUri``.
    ///   - displayName: Optional. Display name of the file data. (Gemini Enterprise Agent Platform only). For more details, see ``displayName``.
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