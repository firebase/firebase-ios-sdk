// Copyright 2024 Google LLC
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
import VertexAITestApp
import XCTest

// TODO(#14405): Migrate to Swift Testing and parameterize tests to run on both `v1` and `v1beta`.
final class IntegrationTests: XCTestCase {
  // Set temperature, topP and topK to lowest allowed values to make responses more deterministic.
  let generationConfig = GenerationConfig(
    temperature: 0.0,
    topP: 0.0,
    topK: 1,
    responseMIMEType: "text/plain"
  )
  let systemInstruction = ModelContent(
    role: "system",
    parts: "You are a friendly and helpful assistant."
  )
  let safetySettings = [
    SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove, method: .probability),
    SafetySetting(harmCategory: .hateSpeech, threshold: .blockLowAndAbove, method: .severity),
    SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .dangerousContent, threshold: .blockLowAndAbove),
    SafetySetting(harmCategory: .civicIntegrity, threshold: .blockLowAndAbove),
  ]
  // Candidates and total token counts may differ slightly between runs due to whitespace tokens.
  let tokenCountAccuracy = 1

  var vertex: VertexAI!
  var model: GenerativeModel!
  var storage: Storage!
  var userID1 = ""

  override func setUp() async throws {
    userID1 = try await TestHelpers.getUserID()
    vertex = VertexAI.vertexAI()
    model = vertex.generativeModel(
      modelName: "gemini-2.0-flash",
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      tools: [],
      toolConfig: .init(functionCallingConfig: .none()),
      systemInstruction: systemInstruction
    )

    storage = Storage.storage()
  }

  // MARK: - Count Tokens

  func testCountTokens_text() async throws {
    let prompt = "Why is the sky blue?"
    model = vertex.generativeModel(
      modelName: "gemini-1.5-pro",
      generationConfig: generationConfig,
      safetySettings: [
        SafetySetting(harmCategory: .harassment, threshold: .blockLowAndAbove, method: .severity),
        SafetySetting(harmCategory: .hateSpeech, threshold: .blockMediumAndAbove),
        SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockOnlyHigh),
        SafetySetting(harmCategory: .dangerousContent, threshold: .blockNone),
        SafetySetting(harmCategory: .civicIntegrity, threshold: .off, method: .probability),
      ],
      toolConfig: .init(functionCallingConfig: .auto()),
      systemInstruction: systemInstruction
    )

    let response = try await model.countTokens(prompt)

    #expect(response.totalTokens == 14)
    #expect(response.totalBillableCharacters == 51)
    #expect(response.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(response.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == 14)
  }

  #if canImport(UIKit)
    func testCountTokens_image_inlineData() async throws {
      guard let image = UIImage(systemName: "cloud") else {
        Issue.record("Image not found.")
        return
      }

      let response = try await model.countTokens(image)

      #expect(response.totalTokens == 266)
      #expect(response.totalBillableCharacters == 35)
      #expect(response.promptTokensDetails.count == 2, "Expected image prompt and system instruction")
      let textPromptTokensDetails = try #require(response.promptTokensDetails.first {
        $0.modality == .text
      }) // System instruction
      #expect(textPromptTokensDetails.tokenCount == 8)
      let imagePromptTokenDetails = try #require(response.promptTokensDetails.first {
        $0.modality == .image
      })
      #expect(imagePromptTokenDetails.tokenCount == 258)
    }
  #endif // canImport(UIKit)

  func testCountTokens_image_fileData_public() async throws {
    let storageRef = storage.reference(withPath: "vertexai/public/green.png")
    let fileData = FileDataPart(uri: storageRef.gsURI, mimeType: "image/png")

    let response = try await model.countTokens(fileData)

    #expect(response.totalTokens == 266)
    #expect(response.totalBillableCharacters == 35)
    #expect(response.promptTokensDetails.count == 2, "Expected image prompt and system instruction")
    let textPromptTokensDetails = try #require(response.promptTokensDetails.first {
      $0.modality == .text
    }) // System instruction
    #expect(textPromptTokensDetails.tokenCount == 8)
    let imagePromptTokenDetails = try #require(response.promptTokensDetails.first {
      $0.modality == .image
    })
    #expect(imagePromptTokenDetails.tokenCount == 258)
  }

  func testCountTokens_image_fileData_requiresAuth_signedIn() async throws {
    let storageRef = storage.reference(withPath: "vertexai/authenticated/all_users/yellow.jpg")
    let fileData = FileDataPart(uri: storageRef.gsURI, mimeType: "image/jpeg")

    let response = try await model.countTokens(fileData)

    #expect(response.totalTokens == 266)
    #expect(response.totalBillableCharacters == 35)
  }

  func testCountTokens_image_fileData_requiresUserAuth_userSignedIn() async throws {
    let storageRef = storage.reference(withPath: "vertexai/authenticated/user/\(userID1)/red.webp")

    let fileData = FileDataPart(uri: storageRef.gsURI, mimeType: "image/webp")

    let response = try await model.countTokens(fileData)

    #expect(response.totalTokens == 266)
    #expect(response.totalBillableCharacters == 35)
  }

  func testCountTokens_image_fileData_requiresUserAuth_wrongUser_permissionDenied() async throws {
    let userID = "3MjEzU6JIobWvHdCYHicnDMcPpQ2"
    let storageRef = storage.reference(withPath: "vertexai/authenticated/user/\(userID)/pink.webp")

    let fileData = FileDataPart(uri: storageRef.gsURI, mimeType: "image/webp")

    // Expect a permission denied error (403).
    await #expect(throws: VertexAIError.self) {
        try await model.countTokens(fileData)
    } is: { error in
      let errorDescription = String(describing: error)
      #expect(errorDescription.contains("403"))
      #expect(errorDescription.contains("The caller does not have permission"))
    }
  }

  func testCountTokens_functionCalling() async throws {
    let sumDeclaration = FunctionDeclaration(
      name: "sum",
      description: "Adds two integers.",
      parameters: ["x": .integer(), "y": .integer()]
    )
    model = vertex.generativeModel(
      modelName: "gemini-2.0-flash",
      tools: [.functionDeclarations([sumDeclaration])],
      toolConfig: .init(functionCallingConfig: .any(allowedFunctionNames: ["sum"]))
    )
    let prompt = "What is 10 + 32?"
    let sumCall = FunctionCallPart(name: "sum", args: ["x": .number(10), "y": .number(32)])
    let sumResponse = FunctionResponsePart(name: "sum", response: ["result": .number(42)])

    let response = try await model.countTokens([
      ModelContent(role: "user", parts: prompt),
      ModelContent(role: "model", parts: sumCall),
      ModelContent(role: "function", parts: sumResponse),
    ])

    #expect(response.totalTokens == 24)
    #expect(response.totalBillableCharacters == 71)
    #expect(response.promptTokensDetails.count == 1)
    let promptTokensDetails = try #require(response.promptTokensDetails.first)
    #expect(promptTokensDetails.modality == .text)
    #expect(promptTokensDetails.tokenCount == 24)
  }

  func testCountTokens_appCheckNotConfigured_shouldFail() async throws {
    let app = try #require(FirebaseApp.app(name: FirebaseAppNames.appCheckNotConfigured))
    let vertex = VertexAI.vertexAI(app: app)
    let model = vertex.generativeModel(modelName: "gemini-2.0-flash")
    let prompt = "Why is the sky blue?"

    // Expect an App Check error.
    await #expect(throws: VertexAIError.self) {
        try await model.countTokens(prompt)
    } is: { error in
      let errorDescription = String(describing: error)
      #expect(errorDescription.contains("Firebase App Check token is invalid"))
    }
  }
}

extension StorageReference {
  var gsURI: String {
    return "gs://\(bucket)/\(fullPath)"
  }
}
