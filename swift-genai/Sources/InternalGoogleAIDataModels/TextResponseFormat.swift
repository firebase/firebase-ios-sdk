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
public import InternalSharedDataModels


extension GoogleAI {
  /// Configuration for text output format.
  public struct TextResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. The MIME type of the text output.
    public var mimeType: MimeType?
    
    /// Optional. The JSON schema that the output should conform to. Only applicable when mime_type is APPLICATION_JSON.
    public var schema: JSONValue?
    
    /// Creates a new `TextResponseFormat`.
    public init(
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