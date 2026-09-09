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
    /// **[Public Preview]** Creates a ``GeminiLanguageModel`` instance.
    ///
    /// > Warning: This API is a public preview and may be subject to change.
    ///
    /// The returned model conforms to Apple's
    /// [`LanguageModel`](https://developer.apple.com/documentation/foundationmodels/languagemodel)
    /// protocol and can be used with `LanguageModelSession` in Apple's Foundation Models
    /// framework.
    ///
    /// - Parameter name: The identifier of the Gemini model to use; see
    ///   [available model
    /// names](https://firebase.google.com/docs/ai-logic/models#available-model-names)
    ///   for a list of supported model names.
    /// - Returns: A ``GeminiLanguageModel`` configured for this `FirebaseAI` instance.
    @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    func geminiLanguageModel(name: String) -> GeminiLanguageModel {
      GeminiLanguageModel(name: name, firebaseAI: self)
    }
  }
#endif // compiler(>=6.4) && canImport(FoundationModels) && canImport(GeminiLanguageModel)
