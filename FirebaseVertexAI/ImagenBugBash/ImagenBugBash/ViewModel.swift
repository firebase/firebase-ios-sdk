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

import FirebaseStorage
import FirebaseVertexAI
import SwiftUI

@MainActor
class ViewModel: ObservableObject {
  @Published var images = [UIImage]()
  @Published var isLoading = false

  private let model: ImagenModel

  // 1. Initialize the Vertex AI service
  private let vertexAI = VertexAI.vertexAI()

  // 1b. Initialize Firebase Store if using GCS
  private let storage = Storage.storage()

  init() {
    // 2. Configure Imagen settings
    let modelName = "imagen-3.0-fast-generate-001"
    let safetySettings = ImagenSafetySettings(
      safetyFilterLevel: .blockLowAndAbove,
      personFilterLevel: .blockAll
    )
    var generationConfig = ImagenGenerationConfig()
    generationConfig.numberOfImages = 2
    generationConfig.aspectRatio = .landscape4x3

    // 3. Initialize the Imagen model
    model = vertexAI.imagenModel(
      modelName: modelName,
      generationConfig: generationConfig,
      safetySettings: safetySettings
    )
  }

  // MARK: - Inline Image Generation

  private func generateInlineImages(prompt: String) async throws -> [UIImage] {
    // 4. Call generateImages with the text prompt
    let response = try await model.generateImages(prompt: prompt)

    // 5. Print the reason images were filtered out, if any.
    if let filteredReason = response.filteredReason {
      print("Image(s) Blocked: \(filteredReason)")
    }

    // 6. Convert the image data to UIImage for display in the UI
    return response.images.compactMap { UIImage(data: $0.data) }
  }

  // MARK: - GCS Image Generation

  private func generateGCSImages(prompt: String) async throws -> [UIImage] {
    // 4. Call generateImages with the text prompt and a GCS URI
    let response = try await model.generateImages(
      prompt: prompt,
      gcsURI: "gs://vinf-imagen-bug-bash.firebasestorage.app/public/generated"
    )

    // 5. Convert the image data to UIImage for display in the UI
    if let filteredReason = response.filteredReason {
      print("Image(s) Blocked: \(filteredReason)")
    }

    // 6. Get Firebase Storage references for each of the generated images
    let storageRefs = response.images.compactMap { storage.reference(forURL: $0.gcsURI) }

    // 7. Download images from GCS and convert to UIImage
    var downloadedImages = [UIImage]()
    for storageRef in storageRefs {
      let imageData = try await storageRef.data(maxSize: 2_000_000) // ~2MB max size
      if let image = UIImage(data: imageData) {
        downloadedImages.append(image)
        try await storageRef.delete() // Clean up images from GCS for the bug bash
      }
    }

    return downloadedImages
  }

  // MARK: - Helpers

  func generateImages(prompt: String, isGCS: Bool) {
    guard !isLoading else {
      print("Already generating images...")
      return
    }

    isLoading = true
    Task {
      defer { isLoading = false }
      images.removeAll()
      do {
        if isGCS {
          images = try await generateGCSImages(prompt: prompt)
        } else {
          images = try await generateInlineImages(prompt: prompt)
        }
      } catch {
        print("Error generating images: \(error)")
      }
    }
  }
}
