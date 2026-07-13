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
  /// Google search entry point.
  package struct SearchEntryPoint: Codable, Sendable, Equatable, Hashable {
    /// Optional. Web content snippet that can be embedded in a web page or an app webview.
    package var renderedContent: String?
    
    /// Optional. Base64 encoded JSON representing array of tuple.
    package var sdkBlob: String?
    
    /// Creates a new `SearchEntryPoint`.
    package init(
      renderedContent: String? = nil,
      sdkBlob: String? = nil
    ) {
      self.renderedContent = renderedContent
      self.sdkBlob = sdkBlob
    }
    enum CodingKeys: String, CodingKey {
      case renderedContent = "renderedContent"
      case sdkBlob = "sdkBlob"
    }
  }
}