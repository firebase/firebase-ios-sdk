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

/// An internal data model for `ModelStatus`.
///
/// ### Gemini Developer API
///
/// Type: `GoogleAiGenerativelanguageV1betaModelStatus`
///
/// The status of the underlying model. This is used to indicate the stage of the
/// underlying model and the retirement time if applicable.
///
/// ### Gemini Enterprise Agent Platform
///
/// > Important: This type is not supported in the Gemini Enterprise Agent Platform.
public struct ModelStatus: Codable, Sendable, Equatable, Hashable {
  /// The time at which the model will be retired.
  ///
  /// ### Gemini Developer API
  ///
  /// The time at which the model will be retired.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  public let retirementTime: String?

  /// A message explaining the model status.
  ///
  /// ### Gemini Developer API
  ///
  /// A message explaining the model status.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
  public let message: String?

  /// Creates a new `ModelStatus`.
  ///
  /// - Parameters:
  ///   - retirementTime: The time at which the model will be retired. (Gemini Developer API only).
  /// For more details, see ``retirementTime``.
  ///   - message: A message explaining the model status. (Gemini Developer API only). For more
  /// details, see ``message``.
  public init(retirementTime: String? = nil,
              message: String? = nil) {
    self.retirementTime = retirementTime
    self.message = message
  }

  enum CodingKeys: String, CodingKey {
    case retirementTime
    case message
  }
}
