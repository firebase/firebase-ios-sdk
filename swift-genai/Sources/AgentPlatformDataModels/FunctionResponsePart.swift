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
  /// A datatype containing media that is part of a `FunctionResponse` message. A `FunctionResponsePart` consists of data which has an associated datatype. A `FunctionResponsePart` can only contain one of the accepted types in `FunctionResponsePart.data`. A `FunctionResponsePart` must have a fixed IANA MIME type identifying the type and subtype of the media if the `inline_data` field is filled with raw bytes.
  package struct FunctionResponsePart: Codable, Sendable, Equatable, Hashable {
    /// URI based data.
    package var fileData: FunctionResponseFileData?
    
    /// Inline media bytes.
    package var inlineData: FunctionResponseBlob?
    
    /// Creates a new `FunctionResponsePart`.
    package init(
      fileData: FunctionResponseFileData? = nil,
      inlineData: FunctionResponseBlob? = nil
    ) {
      self.fileData = fileData
      self.inlineData = inlineData
    }
    enum CodingKeys: String, CodingKey {
      case fileData = "fileData"
      case inlineData = "inlineData"
    }
  }
}