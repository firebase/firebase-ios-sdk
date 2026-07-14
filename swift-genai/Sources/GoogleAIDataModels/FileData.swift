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
  /// URI based data.
  public struct FileData: Codable, Sendable, Equatable, Hashable {
    /// Required. URI.
    public var fileUri: String?
    
    /// Optional. The IANA standard MIME type of the source data.
    public var mimeType: String?
    
    /// Creates a new `FileData`.
    public init(
      fileUri: String? = nil,
      mimeType: String? = nil
    ) {
      self.fileUri = fileUri
      self.mimeType = mimeType
    }
    enum CodingKeys: String, CodingKey {
      case fileUri = "fileUri"
      case mimeType = "mimeType"
    }
  }
}