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
  import XCTest

  @testable import FirebaseAILogic

  final class ResponseGenerationOptionsTests: XCTestCase {
    func testGenerationConfigConversion() {
      let config = GenerationConfig(temperature: 0.5, topK: 40)

      let options = config.responseGenerationOptions

      XCTAssertEqual(options.geminiGenerationConfig, config)
      XCTAssertNil(options.foundationModelsGenerationOptions)
    }

    func testGenerationOptionsConversion() {
      let foundationModelsGenerationOptions = FirebaseAI.GenerationOptions(
        sampling: .random(probabilityThreshold: 0.9),
        temperature: 0.5
      )

      let options = foundationModelsGenerationOptions.responseGenerationOptions

      XCTAssertNil(options.geminiGenerationConfig)
      XCTAssertEqual(options.foundationModelsGenerationOptions, foundationModelsGenerationOptions)
    }

    func testFactoryMethods() {
      let config = GenerationConfig(temperature: 0.7, topP: 0.8)
      let foundationModelsGenerationOptions = FirebaseAI.GenerationOptions(
        sampling: .greedy, temperature: 0.4, maximumResponseTokens: 200
      )

      let geminiOptions = ResponseGenerationOptions.gemini(config)
      XCTAssertEqual(geminiOptions.geminiGenerationConfig, config)
      XCTAssertNil(geminiOptions.foundationModelsGenerationOptions)

      let foundationOptions = ResponseGenerationOptions.foundationModels(
        foundationModelsGenerationOptions
      )
      XCTAssertNil(foundationOptions.geminiGenerationConfig)
      XCTAssertEqual(
        foundationOptions.foundationModelsGenerationOptions,
        foundationModelsGenerationOptions
      )

      let hybridOptions = ResponseGenerationOptions.hybrid(
        gemini: config,
        foundationModels: foundationModelsGenerationOptions
      )
      XCTAssertEqual(hybridOptions.geminiGenerationConfig, config)
      XCTAssertEqual(
        hybridOptions.foundationModelsGenerationOptions,
        foundationModelsGenerationOptions
      )
    }

    func testDefaultOptions() {
      let defaultOptions = ResponseGenerationOptions.default

      XCTAssertNil(defaultOptions.geminiGenerationConfig)
      XCTAssertNil(defaultOptions.foundationModelsGenerationOptions)
    }
  }
#endif // compiler(>=6.2.3)
