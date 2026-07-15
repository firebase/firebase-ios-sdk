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
  /// An internal data model for `SearchTypes`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaToolGoogleSearchSearchTypes`
  /// 
  /// Different types of search that can be enabled on the GoogleSearch tool.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ToolGoogleSearchSearchTypes`
  /// 
  /// Different types of search that can be enabled on the GoogleSearch tool.
  package struct SearchTypes: Codable, Sendable, Equatable, Hashable {
    /// Optional. Enables web search. Only text results are returned.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Enables web search. Only text results are returned.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Setting this field enables web search. Only text results are returned.
    package let webSearch: WebSearch?
    
    /// Optional. Enables image search. Image bytes are returned.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Enables image search. Image bytes are returned.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Setting this field enables image search. Image bytes are returned.
    package let imageSearch: ImageSearch?
    

    /// Creates a new `SearchTypes`.
    ///
    /// - Parameters:
    ///   - webSearch: Optional. Enables web search. Only text results are returned. (behavior varies by backend). For more details, see ``webSearch``.
    ///   - imageSearch: Optional. Enables image search. Image bytes are returned. (behavior varies by backend). For more details, see ``imageSearch``.
    package init(
      webSearch: WebSearch? = nil,
      imageSearch: ImageSearch? = nil
    ) {
      self.webSearch = webSearch
      self.imageSearch = imageSearch
    }
    enum CodingKeys: String, CodingKey {
      case webSearch = "webSearch"
      case imageSearch = "imageSearch"
    }
  }
}