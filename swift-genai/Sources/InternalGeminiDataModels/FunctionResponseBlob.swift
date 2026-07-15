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
  /// An internal data model for `FunctionResponseBlob`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaFunctionResponseBlob`
  /// 
  /// Raw media bytes for function response.
  /// 
  /// Text should not be sent as raw bytes, use the 'FunctionResponse.response'
  /// field.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1FunctionResponseBlob`
  /// 
  /// Raw media bytes for function response.
  /// 
  /// Text should not be sent as raw bytes, use the 'text' field.
  package struct FunctionResponseBlob: Codable, Sendable, Equatable, Hashable {
    /// The IANA standard MIME type of the source data.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The IANA standard MIME type of the source data.
    /// Examples:
    ///   - image/png
    ///   - image/jpeg
    /// If an unsupported MIME type is provided, an error will be returned. For a
    /// complete list of supported types, see [Supported file
    /// formats](https://ai.google.dev/gemini-api/docs/prompting_with_media#supported_file_formats).
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The IANA standard MIME type of the source data.
    package let mimeType: String?
    
    /// Raw bytes for media formats.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Raw bytes for media formats.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. Raw bytes.
    package let data: String?
    
    /// Optional. Display name of the blob.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Display name of the blob.
    /// 
    /// Used to provide a label or filename to distinguish blobs.
    /// 
    /// This field is only returned in PromptMessage for prompt management.
    /// It is currently used in the Gemini GenerateContent calls only when server
    /// side tools (code_execution, google_search, and url_context) are enabled.
    package let displayName: String?
    

    /// Creates a new `FunctionResponseBlob`.
    ///
    /// - Parameters:
    ///   - mimeType: The IANA standard MIME type of the source data. (behavior varies by backend). For more details, see ``mimeType``.
    ///   - data: Raw bytes for media formats. (behavior varies by backend). For more details, see ``data``.
    ///   - displayName: Optional. Display name of the blob. (Gemini Enterprise Agent Platform only). For more details, see ``displayName``.
    package init(
      mimeType: String? = nil,
      data: String? = nil,
      displayName: String? = nil
    ) {
      self.mimeType = mimeType
      self.data = data
      self.displayName = displayName
    }
    enum CodingKeys: String, CodingKey {
      case mimeType = "mimeType"
      case data = "data"
      case displayName = "displayName"
    }
  }
}