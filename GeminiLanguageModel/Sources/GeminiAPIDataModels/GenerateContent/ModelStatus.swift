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

/// The status of the underlying model. This is used to indicate the stage of the underlying model
/// and the retirement time if applicable.
///
/// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
package struct ModelStatus: Codable, Sendable, Equatable, Hashable, Buildable {
  /// A message explaining the model status.
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package var message: String?

  /// The stage of the underlying model.
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package var modelStage: ModelStage?

  /// The time at which the model will be retired.
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  package var retirementTime: String?

  /// Initializes a new `ModelStatus`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case message
    case modelStage
    case retirementTime
  }
}
