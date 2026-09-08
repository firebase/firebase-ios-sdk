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

#if compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
  import GeminiLanguageModel

  public extension FirebaseAI {
    /// Creates a new Gemini language model adapter configured with this Firebase AI instance.
    ///
    /// - Parameters:
    ///   - name: The model name (e.g., `"gemini-3.8-flash"`).
    ///   - thinking: An optional thinking configuration for thought summaries. Defaults to `nil`.
    /// - Returns: A configured `GeminiLanguageModel` instance.
    @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    func geminiLanguageModel(name: String,
                             thinking: GeminiLanguageModel.Thinking? = nil) -> GeminiLanguageModel {
      GeminiLanguageModel(firebaseAI: self, name: name, thinking: thinking)
    }
  }
#endif // compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
