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
  /// Partial argument value of the function call.
  /// 
  /// > Important: This type is only available in the Gemini Enterprise Agent Platform.
  package struct PartialArg: Codable, Sendable, Equatable, Hashable {
    /// Optional. Whether this is not the last part of the same json_path. If true, another PartialArg message for the current json_path is expected to follow.
    /// 
    /// > Important: `willContinue` is only available in the Gemini Enterprise Agent Platform.
    package let willContinue: Bool?
    
    /// Optional. Represents a null value.
    /// 
    /// > Important: `nullValue` is only available in the Gemini Enterprise Agent Platform.
    package let nullValue: NullValue?
    
    /// Optional. Represents a boolean value.
    /// 
    /// > Important: `boolValue` is only available in the Gemini Enterprise Agent Platform.
    package let boolValue: Bool?
    
    /// Optional. Represents a double value.
    /// 
    /// > Important: `numberValue` is only available in the Gemini Enterprise Agent Platform.
    package let numberValue: Double?
    
    /// Required. A JSON Path (RFC 9535) to the argument being streamed. https://datatracker.ietf.org/doc/html/rfc9535. e.g. "$.foo.bar[0].data".
    /// 
    /// > Important: `jsonPath` is only available in the Gemini Enterprise Agent Platform.
    package let jsonPath: String?
    
    /// Optional. Represents a string value.
    /// 
    /// > Important: `stringValue` is only available in the Gemini Enterprise Agent Platform.
    package let stringValue: String?
    
    /// Creates a new `PartialArg`.
    package init(
      willContinue: Bool? = nil,
      nullValue: NullValue? = nil,
      boolValue: Bool? = nil,
      numberValue: Double? = nil,
      jsonPath: String? = nil,
      stringValue: String? = nil
    ) {
      self.willContinue = willContinue
      self.nullValue = nullValue
      self.boolValue = boolValue
      self.numberValue = numberValue
      self.jsonPath = jsonPath
      self.stringValue = stringValue
    }
    enum CodingKeys: String, CodingKey {
      case willContinue = "willContinue"
      case nullValue = "nullValue"
      case boolValue = "boolValue"
      case numberValue = "numberValue"
      case jsonPath = "jsonPath"
      case stringValue = "stringValue"
    }
  }
}