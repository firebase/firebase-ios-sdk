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
  /// Partial argument value of the function call.
  package struct PartialArg: Codable, Sendable, Equatable, Hashable {
    /// Optional. Represents a boolean value.
    package var boolValue: Bool?
    
    /// Required. A JSON Path (RFC 9535) to the argument being streamed. https://datatracker.ietf.org/doc/html/rfc9535. e.g. "$.foo.bar[0].data".
    package var jsonPath: String?
    
    /// Optional. Represents a null value.
    package var nullValue: NullValue?
    
    /// Optional. Represents a double value.
    package var numberValue: Double?
    
    /// Optional. Represents a string value.
    package var stringValue: String?
    
    /// Optional. Whether this is not the last part of the same json_path. If true, another PartialArg message for the current json_path is expected to follow.
    package var willContinue: Bool?
    
    /// Creates a new `PartialArg`.
    package init(
      boolValue: Bool? = nil,
      jsonPath: String? = nil,
      nullValue: NullValue? = nil,
      numberValue: Double? = nil,
      stringValue: String? = nil,
      willContinue: Bool? = nil
    ) {
      self.boolValue = boolValue
      self.jsonPath = jsonPath
      self.nullValue = nullValue
      self.numberValue = numberValue
      self.stringValue = stringValue
      self.willContinue = willContinue
    }
    enum CodingKeys: String, CodingKey {
      case boolValue = "boolValue"
      case jsonPath = "jsonPath"
      case nullValue = "nullValue"
      case numberValue = "numberValue"
      case stringValue = "stringValue"
      case willContinue = "willContinue"
    }
  }
}