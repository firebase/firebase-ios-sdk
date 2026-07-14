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
  /// The image output format for generated images.
  /// 
  /// > Important: This type is only available in the Gemini Enterprise Agent Platform.
  package struct ImageConfigImageOutputOptions: Codable, Sendable, Equatable, Hashable {
    /// Optional. The image format that the output should be saved as.
    /// 
    /// > Important: `mimeType` is only available in the Gemini Enterprise Agent Platform.
    package let mimeType: String?
    
    /// Optional. The compression quality of the output image.
    /// 
    /// > Important: `compressionQuality` is only available in the Gemini Enterprise Agent Platform.
    package let compressionQuality: Int?
    
    /// Creates a new `ImageConfigImageOutputOptions`.
    package init(
      mimeType: String? = nil,
      compressionQuality: Int? = nil
    ) {
      self.mimeType = mimeType
      self.compressionQuality = compressionQuality
    }
    enum CodingKeys: String, CodingKey {
      case mimeType = "mimeType"
      case compressionQuality = "compressionQuality"
    }
  }
}