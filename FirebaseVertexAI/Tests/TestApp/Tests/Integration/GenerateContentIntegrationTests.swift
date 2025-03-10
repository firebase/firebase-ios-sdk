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
struct GenerateContentIntegrationTests {
  static let vertexV1Config = APIConfig(service: .vertexAI, version: .v1)
  static let vertexV1BetaConfig = APIConfig(service: .vertexAI, version: .v1beta)
  static let developerV1BetaConfig = APIConfig(
    service: .developer(endpoint: .generativeLanguage),
    version: .v1beta
  )

  // Set temperature, topP and topK to lowest allowed values to make responses more deterministic.
  static let generationConfig = GenerationConfig(
    temperature: 0.0,
    topP: 0.0,
    topK: 1,
    responseMIMEType: "text/plain"
  )
  static let systemInstruction = ModelContent(
    role: "system",
    parts: "You are a friendly and helpful assistant."
  )
  static let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .civicIntegrity, threshold: .blockLowAndAbove),
  ]
  // Candidates and total token counts may differ slightly between runs due to whitespace tokens.
  let tokenCountAccuracy = 1

  let storage: Storage
  let userID1: String

  init() async throws {
    let authResult = try await Auth.auth().signIn(
      withEmail: Credentials.emailAddress1,
      password: Credentials.emailPassword1
    )
    userID1 = authResult.user.uid

    storage = Storage.storage()
  }

  @Test(arguments: [vertexV1Config, vertexV1BetaConfig, developerV1BetaConfig])
  func generateContent(_ apiConfig: APIConfig) async throws {
    let model = GenerateContentIntegrationTests.model(apiConfig: apiConfig)
    let prompt = "Where is Google headquarters located? Answer with the city name only."

    let response = try await model.generateContent(prompt)

    let text = try #require(response.text).trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(text == "Mountain View")

    let usageMetadata = try #require(response.usageMetadata)
    #expect(usageMetadata.promptTokenCount == 21)
    #expect(usageMetadata.candidatesTokenCount.isEqual(to: 3, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.totalTokenCount.isEqual(to: 24, accuracy: tokenCountAccuracy))
    #expect(usageMetadata.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(usageMetadata.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == usageMetadata.promptTokenCount)
    #expect(usageMetadata.candidatesTokensDetails.count == 1)
    let candidatesTokensDetails = try #require(usageMetadata.candidatesTokensDetails.first)
    #expect(candidatesTokensDetails.modality == .text)
    #expect(candidatesTokensDetails.tokenCount == usageMetadata.candidatesTokenCount)
  }

  static func model(apiConfig: APIConfig) -> GenerativeModel {
    return instance(apiConfig: apiConfig).generativeModel(
      modelName: "gemini-2.0-flash",
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      tools: [],
      toolConfig: .init(functionCallingConfig: .none()),
      systemInstruction: systemInstruction
    )
  }

  // TODO(andrewheard): Move this helper to a file in the Utilities folder.
  static func instance(apiConfig: APIConfig) -> VertexAI {
    switch apiConfig.service {
    case .vertexAI:
      return VertexAI.vertexAI(app: nil, location: "us-central1", apiConfig: apiConfig)
    case .developer:
      return VertexAI.vertexAI(app: nil, location: nil, apiConfig: apiConfig)
    }
  }
}

// TODO(andrewheard): Move this extension to a file in the Utilities folder.
extension Numeric where Self: Strideable, Self.Stride.Magnitude: Comparable {
  func isEqual(to other: Self, accuracy: Self.Stride) -> Bool {
    return distance(to: other).magnitude < accuracy.magnitude
  }
}
