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
  /// Provides a ``HybridModel`` for an instance of ``FirebaseAI``.
  public struct HybridModelProvider: LanguageModelProvider {
    let primary: any LanguageModelProvider
    let secondary: any LanguageModelProvider

    init(primary: any LanguageModelProvider, secondary: any LanguageModelProvider) {
      self.primary = primary
      self.secondary = secondary
    }

    /// Returns an instance of the ``LanguageModel`` corresponding to this provider.
    ///
    /// > Important: This method is for **internal use only** and may change at any time.
    ///
    /// - Parameter firebaseAI: A ``FirebaseAI`` instance that provides necessary context for
    ///   instantiating the model, such as the API configuration.
    public func _languageModel(firebaseAI: FirebaseAI) -> any LanguageModel {
      return HybridModel(
        primary: primary._languageModel(firebaseAI: firebaseAI),
        secondary: secondary._languageModel(firebaseAI: firebaseAI)
      )
    }
  }
#endif // compiler(>=6.2.3)
