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

#if canImport(UIKit)
  import UIKit
#endif // canImport(UIKit)

@Suite(
  .enabled(
    if: ProcessInfo.processInfo.environment["VTXIntegrationImagen"] != nil,
    "Only runs if the environment variable VTXIntegrationImagen is set."
  ),
  .serialized
)
struct ImagenIntegrationTests {
  var vertex: VertexAI
  var storage: Storage
  var userID1: String

  init() async throws {
    let authResult = try await Auth.auth().signIn(
      withEmail: Credentials.emailAddress1,
      password: Credentials.emailPassword1
    )
    userID1 = authResult.user.uid

    vertex = VertexAI.vertexAI()
    storage = Storage.storage()
  }

  @Test func generateImage_inlineImage() async throws {
    let generationConfig = ImagenGenerationConfig(
      negativePrompt: "snow, frost",
      aspectRatio: .portrait3x4,
      imageFormat: .png(),
      addWatermark: false
    )
    let model = vertex.imagenModel(
      modelName: "imagen-3.0-generate-002",
      generationConfig: generationConfig,
      safetySettings: ImagenSafetySettings(
        safetyFilterLevel: .blockLowAndAbove,
        personFilterLevel: .allowAdult
      )
    )
    let imagePrompt = "A woman, 35mm portrait, in front of a mountain range"

    let response = try await model.generateImages(prompt: imagePrompt)

    #expect(response.filteredReason == nil)
    #expect(response.images.count == 1)
    let image = try #require(response.images.first)
    #expect(image.mimeType == "image/png")
    #expect(image.data.isEmpty == false)
    #if canImport(UIKit)
      let uiImage = try #require(UIImage(data: image.data))
      #expect(uiImage.size.width == 896.0)
      #expect(uiImage.size.height == 1280.0)
    #endif // canImport(UIKit)
  }

  @Test func generateImages_gcsImages() async throws {
    let generationConfig = ImagenGenerationConfig(
      numberOfImages: 3,
      aspectRatio: .landscape16x9,
      imageFormat: .jpeg(compressionQuality: 60),
      addWatermark: true
    )
    let model = vertex.imagenModel(
      modelName: "imagen-3.0-fast-generate-001",
      generationConfig: generationConfig,
      safetySettings: ImagenSafetySettings(
        safetyFilterLevel: .blockMediumAndAbove,
        personFilterLevel: .blockAll
      )
    )
    let prompt = "A dense jungle with light streaming through the treetops"
    let storageRef = storage.reference(
      withPath: "/vertexai/imagen/authenticated/user/\(userID1)"
    )

    let response = try await model.generateImages(prompt: prompt, gcsUri: storageRef.gsURI)

    #expect(response.filteredReason == nil)
    #expect(response.images.count == generationConfig.numberOfImages)
    for image in response.images {
      #expect(image.mimeType == "image/jpeg")
      let imageRef = storage.reference(forURL: image.gcsURI)
      let imageData = try await imageRef.data(maxSize: 1_000_000) // ~1MB
      #expect(imageData.isEmpty == false)
      #if canImport(UIKit)
        let uiImage = try #require(UIImage(data: imageData))
        #expect(uiImage.size.width == 1408.0)
        #expect(uiImage.size.height == 768.0)
      #endif // canImport(UIKit)
      try await imageRef.delete()
    }
  }

  @Test func generateImage_allImagesFilteredOut() async throws {
    let generationConfig = ImagenGenerationConfig(numberOfImages: 2, imageFormat: .jpeg())
    let model = vertex.imagenModel(
      modelName: "imagen-3.0-fast-generate-001",
      generationConfig: generationConfig,
      safetySettings: ImagenSafetySettings(
        safetyFilterLevel: .blockLowAndAbove,
        personFilterLevel: .blockAll
      )
    )
    let imagePrompt = "A woman, 35mm portrait, in front of a mountain range"

    let response = try await model.generateImages(prompt: imagePrompt)

    #expect(response.images.isEmpty)
    let filteredReason = try #require(response.filteredReason)
    // 39322892: Detects a person or face when it isn't allowed due to the request safety settings.
    #expect(filteredReason.contains("39322892"))
    // TODO(#14221): Update implementation and test to throw an exception when all filtered out.
  }

  // TODO(#14221): Add an integration test for the prompt being blocked.

  // TODO(#14221): Add integration tests for validating that Storage Rules are enforced.
}
