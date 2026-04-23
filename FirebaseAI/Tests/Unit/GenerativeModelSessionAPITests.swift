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
      _ = GenerativeModelSession(model: geminiModel)

      // Initialize a session with a `HybridModelProvider`
      _ = ai.generativeModelSession(
        model: .hybridModel(
          primary: geminiModel,
          secondary: .geminiModel(name: "gemini-flash-lite-latest")
        )
      )

      // Initialize a session with a `HybridModel`
      let gemmaModel = ai.geminiModel(name: "gemma-4-31b-it")
      let hybridModel = HybridModel(primary: gemmaModel, secondary: geminiModel)
      _ = GenerativeModelSession(model: hybridModel)

      // Variadic examples:
      // #1
      _ = ai.generativeModelSession(
        model: .hybridModel(models:
          .geminiModel(name: "gemini-3.1-flash-lite-preview"),
          .geminiModel(name: "gemini-2.5-flash-lite"))
      )
      // #2
      _ = GenerativeModelSession(model: HybridModel(models: gemmaModel, geminiModel))
      // #3
      let modelNames = ["gemini-3.1-flash-lite-preview", "gemini-2.5-flash-lite"]
      let hybridModel2 = HybridModel(models: modelNames.map { ai.geminiModel(name: $0) })
      _ = GenerativeModelSession(model: hybridModel2)
    }
  }
#endif // compiler(>=6.2.3)
