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
  /// User provided metadata about the GroundingFact.
  /// 
  /// > Important: This type is only available in the Gemini Developer API.
  package struct GroundingChunkCustomMetadata: Codable, Sendable, Equatable, Hashable {
    /// Optional. The string value of the metadata.
    /// 
    /// > Important: `stringValue` is only available in the Gemini Developer API.
    package let stringValue: String?
    
    /// Optional. The numeric value of the metadata. The expected range for this value depends on the specific `key` used.
    /// 
    /// > Important: `numericValue` is only available in the Gemini Developer API.
    package let numericValue: Double?
    
    /// Optional. A list of string values for the metadata.
    /// 
    /// > Important: `stringListValue` is only available in the Gemini Developer API.
    package let stringListValue: GroundingChunkStringList?
    
    /// The key of the metadata.
    /// 
    /// > Important: `key` is only available in the Gemini Developer API.
    package let key: String?
    
    /// Creates a new `GroundingChunkCustomMetadata`.
    package init(
      stringValue: String? = nil,
      numericValue: Double? = nil,
      stringListValue: GroundingChunkStringList? = nil,
      key: String? = nil
    ) {
      self.stringValue = stringValue
      self.numericValue = numericValue
      self.stringListValue = stringListValue
      self.key = key
    }
    enum CodingKeys: String, CodingKey {
      case stringValue = "stringValue"
      case numericValue = "numericValue"
      case stringListValue = "stringListValue"
      case key = "key"
    }
  }
}