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

public import Foundation



extension GoogleAI {
  /// The status of the underlying model. This is used to indicate the stage of the underlying model and the retirement time if applicable.
  package struct ModelStatus: Codable, Sendable, Equatable, Hashable {
    /// A message explaining the model status.
    package var message: String?
    
    /// The stage of the underlying model.
    package var modelStage: ModelStage?
    
    /// The time at which the model will be retired.
    package var retirementTime: Date?
    
    /// Creates a new `ModelStatus`.
    package init(
      message: String? = nil,
      modelStage: ModelStage? = nil,
      retirementTime: Date? = nil
    ) {
      self.message = message
      self.modelStage = modelStage
      self.retirementTime = retirementTime
    }
    enum CodingKeys: String, CodingKey {
      case message = "message"
      case modelStage = "modelStage"
      case retirementTime = "retirementTime"
    }
  }
}