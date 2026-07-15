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
  /// An internal data model for `CodeExecutionResult`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `CodeExecutionResult`
  /// 
  /// An element in the history that represents the result of executing the
  /// `ExecutableCode` and always follows a `part` containing the `ExecutableCode`.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1CodeExecutionResult`
  /// 
  /// Result of executing the ExecutableCode.
  /// 
  /// Generated only when the `CodeExecution` tool is used.
  package struct CodeExecutionResult: Codable, Sendable, Equatable, Hashable {
    /// Required. Outcome of the code execution.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. Outcome of the code execution.
    /// String representation of a Gemini CodeExecutionResult.Outcome enum
    /// http://google3/google/ai/generativelanguage/v1main/content.proto?q=symbol:%5CbOutcome%5Cb
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. Outcome of the code execution.
    package let outcome: String
    
    /// Optional. Contains stdout when code execution is successful; stderr or other
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Contains stdout when code execution is successful; stderr or other
    /// description otherwise.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Contains stdout when code execution is successful, stderr or other
    /// description otherwise.
    package let output: String?
    
    /// Optional. The identifier of the `ExecutableCode` part this result is for.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The identifier of the `ExecutableCode` part this result is for.
    /// Only populated if the corresponding `ExecutableCode` has an id.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let id: String?
    

    /// Creates a new `CodeExecutionResult`.
    ///
    /// - Parameters:
    ///   - outcome: Required. Outcome of the code execution. (behavior varies by backend). For more details, see ``outcome``.
    ///   - output: Optional. Contains stdout when code execution is successful; stderr or other (behavior varies by backend). For more details, see ``output``.
    ///   - id: Optional. The identifier of the `ExecutableCode` part this result is for. (Gemini Developer API only). For more details, see ``id``.
    package init(
      outcome: String,
      output: String? = nil,
      id: String? = nil
    ) {
      self.outcome = outcome
      self.output = output
      self.id = id
    }
    enum CodingKeys: String, CodingKey {
      case outcome = "outcome"
      case output = "output"
      case id = "id"
    }
  }
}