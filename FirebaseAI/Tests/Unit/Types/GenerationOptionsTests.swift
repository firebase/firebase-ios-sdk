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
  @testable import FirebaseAILogic
  import XCTest

  #if canImport(FoundationModels)
    import FoundationModels
  #endif

  final class GenerationOptionsTests: XCTestCase {
    #if canImport(FoundationModels)
      @available(iOS 26.0, macOS 26.0, *)
      @available(tvOS, unavailable)
      @available(watchOS, unavailable)
      func testConversionToFoundationModels() throws {
        let options = FirebaseAI.GenerationOptions(
          sampling: .greedy,
          temperature: 0.5,
          maximumResponseTokens: 100
        )

        let afmOptions = options.toFoundationModels()

        XCTAssertEqual(afmOptions.temperature, 0.5)
        XCTAssertEqual(afmOptions.maximumResponseTokens, 100)
        XCTAssertNotNil(afmOptions.sampling)
        XCTAssertEqual(afmOptions.sampling, .greedy)
      }
    #endif // canImport(FoundationModels)

    func testEquatable_emptyOptions() throws {
      let options = FirebaseAI.GenerationOptions()

      XCTAssertNil(options.sampling)
      XCTAssertNil(options.temperature)
      XCTAssertNil(options.maximumResponseTokens)
    }

    func testGenerationSchema_greedy() throws {
      let temperature = 0.9
      let maximumResponseTokens = 200
      let options = FirebaseAI.GenerationOptions(
        sampling: .greedy,
        temperature: temperature,
        maximumResponseTokens: maximumResponseTokens
      )

      XCTAssertEqual(options.sampling, .greedy)
      XCTAssertEqual(options.temperature, temperature)
      XCTAssertEqual(options.maximumResponseTokens, maximumResponseTokens)
    }

    func testGenerationSchema_probabilityThreshold() throws {
      let topP = 0.8
      let seed: UInt64 = 5_000_000_000
      let temperature = 0.6
      let maximumResponseTokens = 80
      let options = FirebaseAI.GenerationOptions(
        sampling: .random(probabilityThreshold: topP, seed: seed),
        temperature: temperature,
        maximumResponseTokens: maximumResponseTokens
      )

      XCTAssertEqual(options.sampling, .random(probabilityThreshold: topP, seed: seed))
      XCTAssertEqual(options.temperature, temperature)
      XCTAssertEqual(options.maximumResponseTokens, maximumResponseTokens)
    }

    func testGenerationSchema_topK() throws {
      let topK = 5
      let seed: UInt64 = 6_000_000_000
      let temperature = 0.4
      let maximumResponseTokens = 1000
      let options = FirebaseAI.GenerationOptions(
        sampling: .random(top: topK, seed: seed),
        temperature: temperature,
        maximumResponseTokens: maximumResponseTokens
      )

      XCTAssertEqual(options.sampling, .random(top: topK, seed: seed))
      XCTAssertEqual(options.temperature, temperature)
      XCTAssertEqual(options.maximumResponseTokens, maximumResponseTokens)
    }
  }
#endif // compiler(>=6.2.3)
