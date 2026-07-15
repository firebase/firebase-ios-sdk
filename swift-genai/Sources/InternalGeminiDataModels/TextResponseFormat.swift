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
package import InternalSharedDataModels


extension GeminiDataModels {
  /// An internal data model for `TextResponseFormat`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaTextResponseFormat`
  /// 
  /// Configuration for text output format.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1TextResponseFormat`
  /// 
  /// Configuration for text-specific output formatting.
  package struct TextResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. The MIME type of the text output.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The MIME type of the text output.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The IANA standard MIME type of the response.
    package let mimeType: MimeType?
    
    /// Optional. The JSON schema that the output should conform to. Only applicable when
    /// mime_type is APPLICATION_JSON.
    package let schema: JSONValue?
    

    /// Creates a new `TextResponseFormat`.
    ///
    /// - Parameters:
    ///   - mimeType: Optional. The MIME type of the text output. (behavior varies by backend). For more details, see ``mimeType``.
    ///   - schema: Optional. The JSON schema that the output should conform to. Only applicable when
    package init(
      mimeType: MimeType? = nil,
      schema: JSONValue? = nil
    ) {
      self.mimeType = mimeType
      self.schema = schema
    }
    enum CodingKeys: String, CodingKey {
      case mimeType = "mimeType"
      case schema = "schema"
    }
  }
}