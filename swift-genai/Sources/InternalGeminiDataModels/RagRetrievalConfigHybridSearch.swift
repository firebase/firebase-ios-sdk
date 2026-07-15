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
  /// An internal data model for `RagRetrievalConfigHybridSearch`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1RagRetrievalConfigHybridSearch`
  /// 
  /// Config for Hybrid Search.
  package struct RagRetrievalConfigHybridSearch: Codable, Sendable, Equatable, Hashable {
    /// Optional. Alpha value controls the weight between dense and sparse vector search
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Alpha value controls the weight between dense and sparse vector search
    /// results. The range is [0, 1], while 0 means sparse vector search only
    /// and 1 means dense vector search only. The default value is 0.5 which
    /// balances sparse and dense vector search equally.
    package let alpha: Double?
    

    /// Creates a new `RagRetrievalConfigHybridSearch`.
    ///
    /// - Parameters:
    ///   - alpha: Optional. Alpha value controls the weight between dense and sparse vector search (Gemini Enterprise Agent Platform only). For more details, see ``alpha``.
    package init(
      alpha: Double? = nil
    ) {
      self.alpha = alpha
    }
    enum CodingKeys: String, CodingKey {
      case alpha = "alpha"
    }
  }
}