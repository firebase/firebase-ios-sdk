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
  /// An internal data model for `PartialArg`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1PartialArg`
  /// 
  /// Partial argument value of the function call.
  package struct PartialArg: Codable, Sendable, Equatable, Hashable {
    /// Optional. Represents a null value.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Represents a null value.
    package let nullValue: NullValue?
    
    /// Optional. Represents a double value.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Represents a double value.
    package let numberValue: Double?
    
    /// Optional. Represents a string value.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Represents a string value.
    package let stringValue: String?
    
    /// Optional. Represents a boolean value.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Represents a boolean value.
    package let boolValue: Bool?
    
    /// Required. A JSON Path (RFC 9535) to the argument being streamed.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. A JSON Path (RFC 9535) to the argument being streamed.
    /// https://datatracker.ietf.org/doc/html/rfc9535. e.g. "$.foo.bar[0].data".
    package let jsonPath: String
    
    /// Optional. Whether this is not the last part of the same json_path.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Whether this is not the last part of the same json_path.
    /// If true, another PartialArg message for the current json_path is expected
    /// to follow.
    package let willContinue: Bool?
    

    /// Creates a new `PartialArg`.
    ///
    /// - Parameters:
    ///   - nullValue: Optional. Represents a null value. (Gemini Enterprise Agent Platform only). For more details, see ``nullValue``.
    ///   - numberValue: Optional. Represents a double value. (Gemini Enterprise Agent Platform only). For more details, see ``numberValue``.
    ///   - stringValue: Optional. Represents a string value. (Gemini Enterprise Agent Platform only). For more details, see ``stringValue``.
    ///   - boolValue: Optional. Represents a boolean value. (Gemini Enterprise Agent Platform only). For more details, see ``boolValue``.
    ///   - jsonPath: Required. A JSON Path (RFC 9535) to the argument being streamed. (Gemini Enterprise Agent Platform only). For more details, see ``jsonPath``.
    ///   - willContinue: Optional. Whether this is not the last part of the same json_path. (Gemini Enterprise Agent Platform only). For more details, see ``willContinue``.
    package init(
      nullValue: NullValue? = nil,
      numberValue: Double? = nil,
      stringValue: String? = nil,
      boolValue: Bool? = nil,
      jsonPath: String,
      willContinue: Bool? = nil
    ) {
      self.nullValue = nullValue
      self.numberValue = numberValue
      self.stringValue = stringValue
      self.boolValue = boolValue
      self.jsonPath = jsonPath
      self.willContinue = willContinue
    }
    enum CodingKeys: String, CodingKey {
      case nullValue = "nullValue"
      case numberValue = "numberValue"
      case stringValue = "stringValue"
      case boolValue = "boolValue"
      case jsonPath = "jsonPath"
      case willContinue = "willContinue"
    }
  }
}