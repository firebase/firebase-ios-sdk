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
  /// Different types of search that can be enabled on the GoogleSearch tool.
  public struct ToolGoogleSearchSearchTypes: Codable, Sendable, Equatable, Hashable {
    /// Optional. Setting this field enables image search. Image bytes are returned.
    public var imageSearch: ToolGoogleSearchImageSearch?
    
    /// Optional. Setting this field enables web search. Only text results are returned.
    public var webSearch: ToolGoogleSearchWebSearch?
    
    /// Creates a new `ToolGoogleSearchSearchTypes`.
    public init(
      imageSearch: ToolGoogleSearchImageSearch? = nil,
      webSearch: ToolGoogleSearchWebSearch? = nil
    ) {
      self.imageSearch = imageSearch
      self.webSearch = webSearch
    }
    enum CodingKeys: String, CodingKey {
      case imageSearch = "imageSearch"
      case webSearch = "webSearch"
    }
  }
}