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


extension AgentPlatform {
  /// Raw media bytes for function response. Text should not be sent as raw bytes, use the 'text' field.
  public struct FunctionResponseBlob: Codable, Sendable, Equatable, Hashable {
    /// Required. Raw bytes.
    public var data: String?
    
    /// Optional. Display name of the blob. Used to provide a label or filename to distinguish blobs. This field is only returned in PromptMessage for prompt management. It is currently used in the Gemini GenerateContent calls only when server side tools (code_execution, google_search, and url_context) are enabled.
    public var displayName: String?
    
    /// Required. The IANA standard MIME type of the source data.
    public var mimeType: String?
    
    /// Creates a new `FunctionResponseBlob`.
    public init(
      data: String? = nil,
      displayName: String? = nil,
      mimeType: String? = nil
    ) {
      self.data = data
      self.displayName = displayName
      self.mimeType = mimeType
    }
    enum CodingKeys: String, CodingKey {
      case data = "data"
      case displayName = "displayName"
      case mimeType = "mimeType"
    }
  }
}