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
  /// User provided metadata about the GroundingFact.
  package struct GroundingChunkCustomMetadata: Codable, Sendable, Equatable, Hashable {
    /// The key of the metadata.
    package var key: String?
    
    /// Optional. The numeric value of the metadata. The expected range for this value depends on the specific `key` used.
    package var numericValue: Double?
    
    /// Optional. A list of string values for the metadata.
    package var stringListValue: GroundingChunkStringList?
    
    /// Optional. The string value of the metadata.
    package var stringValue: String?
    
    /// Creates a new `GroundingChunkCustomMetadata`.
    package init(
      key: String? = nil,
      numericValue: Double? = nil,
      stringListValue: GroundingChunkStringList? = nil,
      stringValue: String? = nil
    ) {
      self.key = key
      self.numericValue = numericValue
      self.stringListValue = stringListValue
      self.stringValue = stringValue
    }
    enum CodingKeys: String, CodingKey {
      case key = "key"
      case numericValue = "numericValue"
      case stringListValue = "stringListValue"
      case stringValue = "stringValue"
    }
  }
}