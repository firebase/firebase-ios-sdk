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

import FirebaseAILogic
import FirebaseCore
import XCTest

#if compiler(>=6.2.3)
  final class GenerativeModelSessionAPITests: XCTestCase {
    func codeSamples() async throws {
      let ai = FirebaseAI.firebaseAI()

      // Initialize a session with a Gemini model name
      _ = ai.generativeModelSession(model: "gemini-flash-latest")

      // Initialize a session with a `GeminiModelProvider`
      _ = ai.generativeModelSession(model: .geminiModel(name: "gemini-flash-latest"))

      // Initialize a session with a `GeminiModel`
      let geminiModel = ai.geminiModel(name: "gemini-flash-latest")
      _ = ai.generativeModelSession(model: geminiModel)

      // Initialize a session with a `SystemLanguageModel` as a `LanguageModel`
      let systemModel = FirebaseAI.SystemLanguageModel.default
      _ = ai.generativeModelSession(model: systemModel)

      // Initialize a session with a `SystemLanguageModel` as a `LanguageModelProvider`
      _ = ai.generativeModelSession(model: .systemModel())

      // Initialize a session with a `HybridModelProvider` of cloud models
      _ = ai.generativeModelSession(
        model: .hybridModel(
          primary: geminiModel,
          secondary: .geminiModel(name: "gemini-flash-lite-latest")
        )
      )

      // Initialize a session with a `HybridModelProvider` of cloud and on-device models
      _ = ai.generativeModelSession(
        model: .hybridModel(
          primary: .systemModel(),
          secondary: .geminiModel(name: "gemini-flash-lite-latest")
        )
      )

      // Initialize a session with a `HybridModel` of cloud models
      let gemmaModel = ai.geminiModel(name: "gemma-4-31b-it")
      let cloudHybridModel = HybridModel(primary: gemmaModel, secondary: geminiModel)
      _ = ai.generativeModelSession(model: cloudHybridModel)

      // Initialize a session with a `HybridModel` of cloud and on-device models
      let hybridModel = HybridModel(primary: systemModel, secondary: geminiModel)
      _ = ai.generativeModelSession(model: hybridModel)
    }
  }
#endif // compiler(>=6.2.3)
