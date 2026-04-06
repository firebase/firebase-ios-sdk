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
import FirebaseAITestApp
import Testing

@Suite(.serialized)
struct JSONDecodingIntegrationTests {
  let generationConfig = GenerationConfig(temperature: 0.0, topP: 0.0, topK: 1)

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashLite),
  ])
  func testNonStreamingUsageMetadata(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig
    )
    let prompt = "Say 'Hello'"

    let response = try await model.generateContent(prompt)

    let usageMetadata = try #require(response.usageMetadata)
    // If decoding failed to find the key due to casing mismatch, it would default to 0.
    // So asserting > 0 verifies successful decoding.
    #expect(usageMetadata.promptTokenCount > 0)
    #expect(usageMetadata.candidatesTokenCount > 0)
    #expect(usageMetadata.totalTokenCount > 0)
  }

  @Test(arguments: [
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2_5_FlashLite),
    (InstanceConfig.googleAI_v1beta, ModelNames.gemini2_5_FlashLite),
  ])
  func testStreamingUsageMetadata(_ config: InstanceConfig, modelName: String) async throws {
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName,
      generationConfig: generationConfig
    )
    let prompt = "Say 'Hello'"

    let stream = try model.generateContentStream(prompt)

    var foundUsageMetadata = false

    for try await response in stream {
      if let usageMetadata = response.usageMetadata {
        // Some backends might only return usageMetadata in the last chunk.
        if usageMetadata.promptTokenCount > 0 {
          foundUsageMetadata = true
          #expect(usageMetadata.totalTokenCount > 0)
        }
      }
    }

    #expect(
      foundUsageMetadata,
      "Usage metadata was not found or had 0 prompt tokens in the stream."
    )
  }
}
