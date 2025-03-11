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

import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import FirebaseVertexAI
import Testing
import VertexAITestApp

@testable import struct FirebaseVertexAI.APIConfig

@Suite(.serialized)
struct CountTokensIntegrationTests {
  let generationConfig = GenerationConfig(
    temperature: 1.2,
    topP: 0.95,
    topK: 32,
    candidateCount: 1,
    maxOutputTokens: 8192,
    presencePenalty: 1.5,
    frequencyPenalty: 1.75,
    stopSequences: ["cat", "dog", "bird"]
  )
  let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .civicIntegrity, threshold: .blockLowAndAbove),
  ]

  @Test(arguments: InstanceConfig.allConfigs)
  func countTokens_text(_ config: InstanceConfig) async throws {
    let prompt = "Why is the sky blue?"
    let model = VertexAI.componentInstance(config).generativeModel(
      modelName: ModelNames.gemini2Flash,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )

    let response = try await model.countTokens(prompt)

    #expect(response.totalTokens == 6)
    switch config.apiConfig.service {
    case .vertexAI:
      #expect(response.totalBillableCharacters == 16)
    case .developer:
      #expect(response.totalBillableCharacters == nil)
    }
    #expect(response.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(response.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == response.totalTokens)
  }
}
