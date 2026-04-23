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

      // Initialize a session with a `GeminiLanguageModelProvider`
      _ = ai.generativeModelSession(model: .gemini(modelName: "gemini-flash-latest"))

      // Initialize a session with a `GeminiLanguageModel` model
      let geminiModel = ai.geminiLanguageModel(modelName: "gemini-flash-latest")
      _ = ai.generativeModelSession(model: geminiModel)
      _ = GenerativeModelSession(model: geminiModel)
    }
  }
#endif // compiler(>=6.2.3)
