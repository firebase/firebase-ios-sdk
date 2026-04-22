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

final class GenerativeModelSessionAPITests: XCTestCase {
  func codeSamples() async throws {
    let ai = FirebaseAI.firebaseAI()

    // Initialize a session with a Gemini model name (released in M179)
    // TODO: Remove M179 note
    let session = ai.generativeModelSession(model: "gemini-flash-latest")

    // Initialize a session with a `GeminiLanguageModelProvider`
    _ = ai.generativeModelSession(model: .gemini(modelName: "gemini-flash-latest"))
    // TODO: Consider `.geminiModel` and `.systemModel`, or `.gemini` and `.system` for symmetry
    _ = ai.generativeModelSession(model: .gemini(modelName: "gemini-flash-latest"))

    // TODO: Initialize a session with a `SystemLanguageModel`
    // NOTE: A `SystemLanguageModel` can conform to `LanguageModelProvider` and `LanguageModel`
    //       since it has no FirebaseAI dependency.
    // _ = ai.generativeModelSession(model: .systemLanguageModel())

    // TODO: Initialize a session with a `HybridLanguageModelProvider`
    // _ = ai.generativeModelSession(
    //   model: .hybrid(
    //     cloud: .gemini(modelName: "gemini-flash-latest"),
    //     onDevice: .systemLanguageModel(),
    //     inferenceMode: .preferOnDevice
    //   )
    // )
    // OR
    // let hybridModel = HybridLanguageModel(
    //   cloud: geminiModel,
    //   onDevice: systemModel,
    //   inferenceMode: .preferOnDevice
    // )
    // _ = ai.generativeModelSession(hybridModel)

    // Initialize a session with a `GeminiLanguageModel` model
    let geminiModel = ai.geminiLanguageModel(modelName: "gemini-flash-latest")
    _ = ai.generativeModelSession(model: geminiModel)
    _ = GenerativeModelSession(model: geminiModel)

    // Initialize a session with a `SystemLanguageModel` model
    let systemModel = FirebaseAI.SystemLanguageModel()
    _ = FirebaseAI.SystemLanguageModel.default
    // TODO: Consider `ai.systemLanguageModel()` for symmetry.
    // TODO: Conform `FirebaseAI.SystemLanguageModel` to `LanguageModel`
    // _ = ai.generativeModelSession(model: systemModel)
    // _ = GenerativeModelSession(model: systemModel)

    // Initialize a session with a `HybridLanguageModel`
    // let hybridModel = ai.hybridLanguageModel(
    //   cloud: geminiModel,
    //   onDevice: systemModel,
    //   inferenceMode: .preferOnDevice
    // )
    // _ = ai.generativeModelSession(model: hybridModel)
    // _ = GenerativeModelSession(model: hybridModel)

    // MARK: Alternative Hybrid model parameter naming

    // let hybridModel = ai.hybridLanguageModel(
    //   primary: FirebaseAI.SystemLanguageModel.default,
    //   secondary: ai.geminiLanguageModel(modelName: "gemini-flash-latest")
    // )
    // OR
    // let hybridModel = HybridLanguageModel(
    //   primary: systemModel,
    //   secondary: geminiModel,
    // )
  }
}
