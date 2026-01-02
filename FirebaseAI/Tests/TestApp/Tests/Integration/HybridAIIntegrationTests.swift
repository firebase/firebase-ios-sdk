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
import FirebaseCore
import Testing

@Suite(.serialized)
struct HybridAIIntegrationTests {
  // Custom list of configs to test Hybrid AI (Cloud + On-Device)
  static let hybridConfigs: [(InstanceConfig, String)] = [
    // Cloud (Gemini)
    (InstanceConfig.vertexAI_v1beta, ModelNames.gemini2FlashLite),
    // On-Device (Apple Foundation Models)
    (InstanceConfig.foundationModels, "system-model"),
  ]

  @Test(arguments: hybridConfigs)
  func generateContent(_ config: InstanceConfig, modelName: String) async throws {
    // 1. Initialize the model using the factory which now supports .foundationModels
    let model = FirebaseAI.componentInstance(config).generativeModel(
      modelName: modelName
    )

    // 2. Define a simple prompt supported by both backends
    let prompt = "What is the capital of France? Answer with the city name only."

    // 3. Execute the request
    // Note: For .foundationModels, this calls the wrapped Apple API.
    // Ideally, we'd handle potential 'unsupported' errors gracefully if running on a device without
    // support.
    let response = try await model.generateContent(prompt)

    // 4. Verify the response
    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)

    // Check for "Paris" (allowing for minor variations or punctuation)
    #expect(text.contains("Paris"))

    // 5. Verify Metadata (Optional, as Apple models might return less metadata)
    let usageMetadata = response.usageMetadata
    if config.serviceName == "Foundation Models" {
      // On-device models might not return token counts or detailed metadata yet
      // but we expect a non-nil response object.
    } else {
      // Cloud models should have usage metadata
      #expect(usageMetadata != nil)
    }
  }
}
