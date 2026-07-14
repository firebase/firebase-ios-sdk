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
  /// A content blob. A Blob contains data of a specific media type. It is used to represent images, audio, and video.
  public struct Blob: Codable, Sendable, Equatable, Hashable {
    /// Required. The raw bytes of the data.
    public var data: String?
    
    /// Optional. The display name of the blob. Used to provide a label or filename to distinguish blobs. This field is only returned in `PromptMessage` for prompt management. It is used in the Gemini calls only when server-side tools (`code_execution`, `google_search`, and `url_context`) are enabled.
    public var displayName: String?
    
    /// Required. The IANA standard MIME type of the source data.
    public var mimeType: String?
    
    /// Creates a new `Blob`.
    public init(
      data: String? = nil,
      displayName: String? = nil,
      mimeType: String? = nil
    ) {
      self.data = data
      self.displayName = displayName
      self.mimeType = mimeType
    }
    enum CodingKeys: String, CodingKey {
      case data = "data"
      case displayName = "displayName"
      case mimeType = "mimeType"
    }
  }
}