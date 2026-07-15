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
  /// An internal data model for `FunctionResponsePart`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaFunctionResponsePart`
  /// 
  /// A datatype containing media that is part of a `FunctionResponse` message.
  /// 
  /// A `FunctionResponsePart` consists of data which has an associated datatype. A
  /// `FunctionResponsePart` can only contain one of the accepted types in
  /// `FunctionResponsePart.data`.
  /// 
  /// A `FunctionResponsePart` must have a fixed IANA MIME type identifying the
  /// type and subtype of the media if the `inline_data` field is filled with raw
  /// bytes.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1FunctionResponsePart`
  /// 
  /// A datatype containing media that is part of a `FunctionResponse` message.
  /// 
  /// A `FunctionResponsePart` consists of data which has an associated datatype. A
  /// `FunctionResponsePart` can only contain one of the accepted types in
  /// `FunctionResponsePart.data`.
  /// 
  /// A `FunctionResponsePart` must have a fixed IANA MIME type identifying the
  /// type and subtype of the media if the `inline_data` field is filled with raw
  /// bytes.
  package struct FunctionResponsePart: Codable, Sendable, Equatable, Hashable {
    /// Inline media bytes.
    package let inlineData: FunctionResponseBlob?
    
    /// URI based data.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// URI based data.
    package let fileData: FunctionResponseFileData?
    

    /// Creates a new `FunctionResponsePart`.
    ///
    /// - Parameters:
    ///   - inlineData: Inline media bytes.
    ///   - fileData: URI based data. (Gemini Enterprise Agent Platform only). For more details, see ``fileData``.
    package init(
      inlineData: FunctionResponseBlob? = nil,
      fileData: FunctionResponseFileData? = nil
    ) {
      self.inlineData = inlineData
      self.fileData = fileData
    }
    enum CodingKeys: String, CodingKey {
      case inlineData = "inlineData"
      case fileData = "fileData"
    }
  }
}