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

import FirebaseAILogic
import FirebaseCore
import XCTest

#if canImport(UIKit)
  import UIKit
#endif // canImport(UIKit)

// These snippet tests are intentionally skipped in CI jobs; see the README file in this directory
// for instructions on running them manually.

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class MultimodalSnippets: XCTestCase {
  let bundle = BundleTestUtil.bundle()
  lazy var model = FirebaseAI.firebaseAI(backend: .vertexAI()).generativeModel(
    modelName: "gemini-2.0-flash"
  )
  lazy var videoURL = {
    guard let url = bundle.url(forResource: "animals", withExtension: "mp4") else {
      fatalError("Video file animals.mp4 not found in Resources.")
    }
    return url
  }()

  lazy var audioURL = {
    guard let url = bundle.url(forResource: "hello-world", withExtension: "mp3") else {
      fatalError("Audio file hello-world.mp3 not found in Resources.")
    }
    return url
  }()

  lazy var pdfURL = {
    guard let url = bundle.url(forResource: "gemini-report", withExtension: "pdf") else {
      fatalError("PDF file gemini-report.pdf not found in Resources.")
    }
    return url
  }()

  override func setUpWithError() throws {
    try FirebaseApp.configureDefaultAppForSnippets()
  }

  override func tearDown() async throws {
    await FirebaseApp.deleteDefaultAppForSnippets()
  }

  // MARK: - Image Input

  #if canImport(UIKit)
    func testMultimodalOneImageNonStreaming() async throws {
      guard let image = UIImage(systemName: "bicycle") else { fatalError() }

      // Provide a text prompt to include with the image
      let prompt = "What's in this picture?"

      // To generate text output, call generateContent and pass in the prompt
      let response = try await model.generateContent(image, prompt)
      print(response.text ?? "No text in response.")
    }

    func testMultimodalOneImageStreaming() async throws {
      guard let image = UIImage(systemName: "bicycle") else { fatalError() }

      // Provide a text prompt to include with the image
      let prompt = "What's in this picture?"

      // To stream generated text output, call generateContentStream and pass in the prompt
      let contentStream = try model.generateContentStream(image, prompt)
      for try await chunk in contentStream {
        if let text = chunk.text {
          print(text)
        }
      }
    }

    func testMultimodalMultiImagesNonStreaming() async throws {
      guard let image1 = UIImage(systemName: "car") else { fatalError() }
      guard let image2 = UIImage(systemName: "car.2") else { fatalError() }

      // Provide a text prompt to include with the images
      let prompt = "What's different between these pictures?"

      // To generate text output, call generateContent and pass in the prompt
      let response = try await model.generateContent(image1, image2, prompt)
      print(response.text ?? "No text in response.")
    }

    func testMultimodalMultiImagesStreaming() async throws {
      guard let image1 = UIImage(systemName: "car") else { fatalError() }
      guard let image2 = UIImage(systemName: "car.2") else { fatalError() }

      // Provide a text prompt to include with the images
      let prompt = "What's different between these pictures?"

      // To stream generated text output, call generateContentStream and pass in the prompt
      let contentStream = try model.generateContentStream(image1, image2, prompt)
      for try await chunk in contentStream {
        if let text = chunk.text {
          print(text)
        }
      }
    }
  #endif // canImport(UIKit)

  // MARK: - Video Input

  func testMultimodalVideoNonStreaming() async throws {
    // Provide the video as `Data` with the appropriate MIME type
    let video = try InlineDataPart(data: Data(contentsOf: videoURL), mimeType: "video/mp4")

    // Provide a text prompt to include with the video
    let prompt = "What is in the video?"

    // To generate text output, call generateContent with the text and video
    let response = try await model.generateContent(video, prompt)
    print(response.text ?? "No text in response.")
  }

  func testMultimodalVideoStreaming() async throws {
    // Provide the video as `Data` with the appropriate MIME type
    let video = try InlineDataPart(data: Data(contentsOf: videoURL), mimeType: "video/mp4")

    // Provide a text prompt to include with the video
    let prompt = "What is in the video?"

    // To stream generated text output, call generateContentStream with the text and video
    let contentStream = try model.generateContentStream(video, prompt)
    for try await chunk in contentStream {
      if let text = chunk.text {
        print(text)
      }
    }
  }

  // MARK: - Audio Input

  func testMultiModalAudioNonStreaming() async throws {
    // Provide the audio as `Data` with the appropriate MIME type
    let audio = try InlineDataPart(data: Data(contentsOf: audioURL), mimeType: "audio/mpeg")

    // Provide a text prompt to include with the audio
    let prompt = "Transcribe what's said in this audio recording."

    // To generate text output, call `generateContent` with the audio and text prompt
    let response = try await model.generateContent(audio, prompt)

    // Print the generated text, handling the case where it might be nil
    print(response.text ?? "No text in response.")
  }

  func testMultiModalAudioStreaming() async throws {
    // Provide the audio as `Data` with the appropriate MIME type
    let audio = try InlineDataPart(data: Data(contentsOf: audioURL), mimeType: "audio/mpeg")

    // Provide a text prompt to include with the audio
    let prompt = "Transcribe what's said in this audio recording."

    // To stream generated text output, call `generateContentStream` with the audio and text prompt
    let contentStream = try model.generateContentStream(audio, prompt)

    // Print the generated text, handling the case where it might be nil
    for try await chunk in contentStream {
      if let text = chunk.text {
        print(text)
      }
    }
  }

  // MARK: - Document Input

  func testMultiModalPDFStreaming() async throws {
    // Provide the PDF as `Data` with the appropriate MIME type
    let pdf = try InlineDataPart(data: Data(contentsOf: pdfURL), mimeType: "application/pdf")

    // Provide a text prompt to include with the PDF file
    let prompt = "Summarize the important results in this report."

    // To stream generated text output, call `generateContentStream` with the PDF file and text
    // prompt
    let contentStream = try model.generateContentStream(pdf, prompt)

    // Print the generated text, handling the case where it might be nil
    for try await chunk in contentStream {
      if let text = chunk.text {
        print(text)
      }
    }
  }

  func testMultiModalPDFNonStreaming() async throws {
    // Provide the PDF as `Data` with the appropriate MIME type
    let pdf = try InlineDataPart(data: Data(contentsOf: pdfURL), mimeType: "application/pdf")

    // Provide a text prompt to include with the PDF file
    let prompt = "Summarize the important results in this report."

    // To generate text output, call `generateContent` with the PDF file and text prompt
    let response = try await model.generateContent(pdf, prompt)

    // Print the generated text, handling the case where it might be nil
    print(response.text ?? "No text in response.")
  }
}
