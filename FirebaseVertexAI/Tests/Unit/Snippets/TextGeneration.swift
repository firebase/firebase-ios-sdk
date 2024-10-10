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

import FirebaseCore
import FirebaseVertexAI
import XCTest

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class TextGeneration: XCTestCase {
  override func setUpWithError() throws {
    try FirebaseApp.configureForSnippets()
  }

  override func tearDown() async throws {
    if let app = FirebaseApp.app() {
      await app.delete()
    }
  }

  func testTextOnlyPrompt() async throws {
    // [START text_gen_text_only_prompt]
    // Initialize the Vertex AI service
    let vertex = VertexAI.vertexAI()

    // Initialize the generative model with a model that supports your use case
    // Gemini 1.5 models are versatile and can be used with all API capabilities
    let model = vertex.generativeModel(modelName: "gemini-1.5-flash")

    // Provide a prompt that contains text
    let prompt = "Write a story about a magic backpack."

    // To generate text output, call generateContent with the text input
    let response = try await model.generateContent(prompt)
    if let text = response.text {
      print(text)
    }
    // [END text_gen_text_only_prompt]
  }

  func testTextOnlyPromptStreaming() async throws {
    // [START text_gen_text_only_prompt_streaming]
    // Initialize the Vertex AI service
    let vertex = VertexAI.vertexAI()

    // Initialize the generative model with a model that supports your use case
    // Gemini 1.5 models are versatile and can be used with all API capabilities
    let model = vertex.generativeModel(modelName: "gemini-1.5-flash")

    // Provide a prompt that contains text
    let prompt = "Write a story about a magic backpack."

    // To stream generated text output, call generateContentStream with the text input
    let contentStream = try await model.generateContentStream(prompt)
    for try await chunk in contentStream {
      if let text = chunk.text {
        print(text)
      }
    }
    // [END text_gen_text_only_prompt_streaming]
  }

  #if canImport(UIKit)
    func testMultimodalOneImagePrompt() async throws {
      // [START text_gen_multimodal_one_image_prompt]
      // Initialize the Vertex AI service
      let vertex = VertexAI.vertexAI()

      // Initialize the generative model with a model that supports your use case
      // Gemini 1.5 models are versatile and can be used with all API capabilities
      let model = vertex.generativeModel(modelName: "gemini-1.5-flash")

      guard let image = UIImage(systemName: "cloud.sun") else { fatalError() }

      // Provide a text prompt to include with the image
      let prompt = "What's in this picture?"

      // To generate text output, call generateContent and pass in the prompt
      let response = try await model.generateContent(image, prompt)
      if let text = response.text {
        print(text)
      }
      // [END text_gen_multimodal_one_image_prompt]
    }

    func testMultimodalOneImagePromptStreaming() async throws {
      // [START text_gen_multimodal_one_image_prompt_streaming]
      // Initialize the Vertex AI service
      let vertex = VertexAI.vertexAI()

      // Initialize the generative model with a model that supports your use case
      // Gemini 1.5 models are versatile and can be used with all API capabilities
      let model = vertex.generativeModel(modelName: "gemini-1.5-flash")

      guard let image = UIImage(systemName: "cloud.sun") else { fatalError() }

      // Provide a text prompt to include with the image
      let prompt = "What's in this picture?"

      // To stream generated text output, call generateContentStream and pass in the prompt
      let contentStream = try await model.generateContentStream(image, prompt)
      for try await chunk in contentStream {
        if let text = chunk.text {
          print(text)
        }
      }
      // [END text_gen_multimodal_one_image_prompt_streaming]
    }

    func testMultimodalMultiImagePrompt() async throws {
      // [START text_gen_multimodal_multi_image_prompt]
      // Initialize the Vertex AI service
      let vertex = VertexAI.vertexAI()

      // Initialize the generative model with a model that supports your use case
      // Gemini 1.5 models are versatile and can be used with all API capabilities
      let model = vertex.generativeModel(modelName: "gemini-1.5-flash")

      guard let image1 = UIImage(systemName: "cloud.sun") else { fatalError() }
      guard let image2 = UIImage(systemName: "cloud.heavyrain") else { fatalError() }

      // Provide a text prompt to include with the images
      let prompt = "What's different between these pictures?"

      // To generate text output, call generateContent and pass in the prompt
      let response = try await model.generateContent(image1, image2, prompt)
      if let text = response.text {
        print(text)
      }
      // [END text_gen_multimodal_multi_image_prompt]
    }

    func testMultimodalMultiImagePromptStreaming() async throws {
      // [START text_gen_multimodal_multi_image_prompt_streaming]
      // Initialize the Vertex AI service
      let vertex = VertexAI.vertexAI()

      // Initialize the generative model with a model that supports your use case
      // Gemini 1.5 models are versatile and can be used with all API capabilities
      let model = vertex.generativeModel(modelName: "gemini-1.5-flash")

      guard let image1 = UIImage(systemName: "cloud.sun") else { fatalError() }
      guard let image2 = UIImage(systemName: "cloud.heavyrain") else { fatalError() }

      // Provide a text prompt to include with the images
      let prompt = "What's different between these pictures?"

      // To stream generated text output, call generateContentStream and pass in the prompt
      let contentStream = try await model.generateContentStream(image1, image2, prompt)
      for try await chunk in contentStream {
        if let text = chunk.text {
          print(text)
        }
      }
      // [END text_gen_multimodal_multi_image_prompt_streaming]
    }
  #endif // canImport(UIKit)
}
