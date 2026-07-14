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




extension GeminiDataModels {
  /// The status of the underlying model. This is used to indicate the stage of the underlying model and the retirement time if applicable.
  /// 
  /// > Important: This type is only available in the Gemini Developer API.
  package struct ModelStatus: Codable, Sendable, Equatable, Hashable {
    /// The time at which the model will be retired.
    /// 
    /// > Important: `retirementTime` is only available in the Gemini Developer API.
    package let retirementTime: Date?
    
    /// The stage of the underlying model.
    /// 
    /// > Important: `modelStage` is only available in the Gemini Developer API.
    package let modelStage: ModelStage?
    
    /// A message explaining the model status.
    /// 
    /// > Important: `message` is only available in the Gemini Developer API.
    package let message: String?
    
    /// Creates a new `ModelStatus`.
    package init(
      retirementTime: Date? = nil,
      modelStage: ModelStage? = nil,
      message: String? = nil
    ) {
      self.retirementTime = retirementTime
      self.modelStage = modelStage
      self.message = message
    }
    enum CodingKeys: String, CodingKey {
      case retirementTime = "retirementTime"
      case modelStage = "modelStage"
      case message = "message"
    }
  }
}