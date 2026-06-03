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

#if compiler(>=6.2.3)
  /// A type that represents a large language model (LLM).
  public protocol LanguageModel: LanguageModelProvider {
    /// Returns the name of the model.
    ///
    /// > Important: This property is for **internal use only** and may change at any time.
    var _modelName: String { get }

    /// Returns a new session for this model.
    ///
    /// > Important: This method is for **internal use only** and may change at any time.
    func _startSession(tools: [any ToolRepresentable]?, instructions: String?) throws
      -> any _ModelSession
  }

  // Default implementation to allow a `LanguageModel` to conform to `LanguageModelProvider`.
  public extension LanguageModel {
    func _languageModel(firebaseAI: FirebaseAI) -> any LanguageModel {
      // A `LanguageModel` can simply provide itself since it is already a `LanguageModel`.
      return self
    }
  }
#endif // compiler(>=6.2.3)
