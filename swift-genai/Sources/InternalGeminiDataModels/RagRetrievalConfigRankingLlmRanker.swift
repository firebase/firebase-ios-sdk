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
  /// An internal data model for `RagRetrievalConfigRankingLlmRanker`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1RagRetrievalConfigRankingLlmRanker`
  /// 
  /// Config for LlmRanker.
  package struct RagRetrievalConfigRankingLlmRanker: Codable, Sendable, Equatable, Hashable {
    /// Optional. The model name used for ranking. See [Supported
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The model name used for ranking. See [Supported
    /// models](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#supported-models).
    package let modelName: String?
    

    /// Creates a new `RagRetrievalConfigRankingLlmRanker`.
    ///
    /// - Parameters:
    ///   - modelName: Optional. The model name used for ranking. See [Supported (Gemini Enterprise Agent Platform only). For more details, see ``modelName``.
    package init(
      modelName: String? = nil
    ) {
      self.modelName = modelName
    }
    enum CodingKeys: String, CodingKey {
      case modelName = "modelName"
    }
  }
}