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
  /// An internal data model for `GroundingChunkCustomMetadata`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGroundingChunkCustomMetadata`
  /// 
  /// User provided metadata about the GroundingFact.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
  package struct GroundingChunkCustomMetadata: Codable, Sendable, Equatable, Hashable {
    /// Optional. The string value of the metadata.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The string value of the metadata.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let stringValue: String?
    
    /// Optional. A list of string values for the metadata.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. A list of string values for the metadata.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let stringListValue: GroundingChunkStringList?
    
    /// Optional. The numeric value of the metadata.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The numeric value of the metadata.
    /// The expected range for this value depends on the specific `key` used.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let numericValue: Double?
    
    /// The key of the metadata.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The key of the metadata.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let key: String?
    

    /// Creates a new `GroundingChunkCustomMetadata`.
    ///
    /// - Parameters:
    ///   - stringValue: Optional. The string value of the metadata. (Gemini Developer API only). For more details, see ``stringValue``.
    ///   - stringListValue: Optional. A list of string values for the metadata. (Gemini Developer API only). For more details, see ``stringListValue``.
    ///   - numericValue: Optional. The numeric value of the metadata. (Gemini Developer API only). For more details, see ``numericValue``.
    ///   - key: The key of the metadata. (Gemini Developer API only). For more details, see ``key``.
    package init(
      stringValue: String? = nil,
      stringListValue: GroundingChunkStringList? = nil,
      numericValue: Double? = nil,
      key: String? = nil
    ) {
      self.stringValue = stringValue
      self.stringListValue = stringListValue
      self.numericValue = numericValue
      self.key = key
    }
    enum CodingKeys: String, CodingKey {
      case stringValue = "stringValue"
      case stringListValue = "stringListValue"
      case numericValue = "numericValue"
      case key = "key"
    }
  }
}