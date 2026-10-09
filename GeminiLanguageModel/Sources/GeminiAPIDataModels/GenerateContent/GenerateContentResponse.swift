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

/// Response message for [PredictionService.GenerateContent].
package struct GenerateContentResponse: Codable, Sendable, Equatable, Hashable, Buildable {
  /// Generated candidates.
  package var candidates: [Candidate]?

  /// Timestamp when the request is made to the server.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var createTime: String?

  /// The current model status of this model.
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package var modelStatus: ModelStatus?

  /// The model version used to generate the response.
  package var modelVersion: String?

  /// Content filter results for a prompt sent in the request. Note: Sent only in the first stream
  /// chunk. Only happens when no candidates were generated due to content violations.
  package var promptFeedback: PromptFeedback?

  /// Response_id is used to identify each response. It is the encoding of the event_id.
  package var responseID: String?

  /// Usage metadata about the response(s).
  package var usageMetadata: UsageMetadata?

  /// Initializes a new `GenerateContentResponse`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case candidates
    case createTime
    case modelStatus
    case modelVersion
    case promptFeedback
    case responseID = "responseId"
    case usageMetadata
  }
}
