// Copyright 2025 Google LLC
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
import FirebaseAITestApp
import Foundation
import Testing

@Suite(.serialized)
struct AutomaticFunctionCallingIntegrationTests {
  // Set temperature to 0 for deterministic output.
  let generationConfig = GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1)
  let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockLowAndAbove),
  ]

  static let modelConfigurations = [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_Flash),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini3FlashPreview),
  ]

  @Test(arguments: modelConfigurations)
  func automaticFunctionCalling_calculator(_ config: InstanceConfig,
                                           modelName: String) async throws {
    let addFunction = makeAddFunction()
    let subtractFunction = makeSubtractFunction()

    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      automaticFunctionTools: [addFunction, subtractFunction]
    )

    let chat = model.startChat()
    let response = try await chat.sendMessage("What is (5 + 3) - 2? Answer with the result.")

    // The model should call add(5, 3) -> 8, then subtract(8, 2) -> 6.
    // The final response should contain "6".
    let text = response.text ?? ""
    #expect(
      text.contains("6"),
      "Response text was empty or didn't contain 6. Full response: \(response)"
    )
  }

  @Test(arguments: modelConfigurations)
  func automaticFunctionCalling_stream_calculator(_ config: InstanceConfig,
                                                  modelName: String) async throws {
    let addFunction = makeAddFunction()

    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      automaticFunctionTools: [addFunction]
    )

    let chat = model.startChat()
    let stream = try chat.sendMessageStream("What is 10 + 20? Answer with the result.")

    var finalResponseText = ""
    for try await chunk in stream {
      if let text = chunk.text {
        finalResponseText += text
      }
    }
    #expect(
      finalResponseText.contains("30"),
      "Response text didn't contain 30. Got: \(finalResponseText)"
    )
  }

  private func makeAddFunction() -> AutomaticFunction {
    AutomaticFunction(
      name: "add",
      description: "Adds two numbers",
      parameters: [
        "a": .double(),
        "b": .double(),
      ],
      optionalParameters: []
    ) { args in
      guard case let .number(a) = args["a"], case let .number(b) = args["b"] else {
        throw NSError(
          domain: "Calculator",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Invalid arguments"]
        )
      }
      return ["result": .number(a + b)]
    }
  }

  private func makeSubtractFunction() -> AutomaticFunction {
    AutomaticFunction(
      name: "subtract",
      description: "Subtracts two numbers",
      parameters: [
        "a": .double(),
        "b": .double(),
      ],
      optionalParameters: []
    ) { args in
      guard case let .number(a) = args["a"], case let .number(b) = args["b"] else {
        throw NSError(
          domain: "Calculator",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Invalid arguments"]
        )
      }
      return ["result": .number(a - b)]
    }
  }

  #if canImport(FoundationModels)
    @Test(arguments: modelConfigurations)
    @available(iOS 26.0, macOS 26.0, *)
    func automaticFunctionCalling_foundationTool(_ config: InstanceConfig,
                                                 modelName: String) async throws {
      let addTool = try AutomaticFunction(AddTool())
      let subtractTool = try AutomaticFunction(SubtractTool())

      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: modelName,
        generationConfig: generationConfig,
        safetySettings: safetySettings,
        automaticFunctionTools: [addTool, subtractTool]
      )

      let chat = model.startChat()
      let response = try await chat.sendMessage("What is (10 + 5) - 3? Answer with the result.")

      let text = response.text ?? ""
      #expect(text.contains("12"), "Response text didn't contain 12. Full response: \(response)")
    }

    @Test(arguments: modelConfigurations)
    @available(iOS 26.0, macOS 26.0, *)
    func automaticFunctionCalling_stream_foundationTool(_ config: InstanceConfig,
                                                        modelName: String) async throws {
      let addTool = try AutomaticFunction(AddTool())
      let subtractTool = try AutomaticFunction(SubtractTool())

      let model = FirebaseAI.componentInstance(config).generativeModel(
        modelName: modelName,
        generationConfig: generationConfig,
        safetySettings: safetySettings,
        automaticFunctionTools: [addTool, subtractTool]
      )

      let chat = model.startChat()
      let stream = try chat.sendMessageStream("What is (10 + 5) - 3? Answer with the result.")

      var finalResponseText = ""
      for try await chunk in stream {
        if let text = chunk.text {
          finalResponseText += text
        }
      }

      #expect(
        finalResponseText.contains("12"),
        "Response text didn't contain 12. Got: \(finalResponseText)"
      )
    }
  #endif
}

#if canImport(FoundationModels)
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  struct AddTool: FoundationModels.Tool {
    let name = "add"
    let description = "Adds two numbers"

    @Generable
    struct Arguments {
      @Guide(description: "First number")
      let a: Double
      @Guide(description: "Second number")
      let b: Double
    }

    typealias Output = Double

    func call(arguments: Arguments) async throws -> Output {
      return arguments.a + arguments.b
    }
  }

  @available(iOS 26.0, macOS 26.0, *)
  struct SubtractTool: FoundationModels.Tool {
    let name = "subtract"
    let description = "Subtracts two numbers"

    @Generable
    struct Arguments {
      @Guide(description: "First number")
      let a: Double
      @Guide(description: "Second number")
      let b: Double
    }

    typealias Output = Double

    func call(arguments: Arguments) async throws -> Output {
      return arguments.a - arguments.b
    }
  }
#endif
