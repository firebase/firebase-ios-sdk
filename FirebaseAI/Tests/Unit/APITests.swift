// Copyright 2023 Google LLC
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

import FirebaseAI
import FirebaseCore
import XCTest
#if canImport(AppKit)
  import AppKit // For NSImage extensions.
#elseif canImport(UIKit)
  import UIKit // For UIImage extensions.
#endif

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class APITests: XCTestCase {
  func codeSamples() async throws {
    let app = FirebaseApp.app()
    let config = GenerationConfig(temperature: 0.2,
                                  topP: 0.1,
                                  topK: 16,
                                  candidateCount: 4,
                                  maxOutputTokens: 256,
                                  stopSequences: ["..."],
                                  responseMIMEType: "text/plain")
    let filters = [SafetySetting(harmCategory: .dangerousContent, threshold: .blockOnlyHigh)]
    let systemInstruction = ModelContent(
      role: "system",
      parts: TextPart("Talk like a pirate.")
    )

    let requestOptions = RequestOptions()
    let _ = RequestOptions(timeout: 30.0)

    // Instantiate Firebase AI SDK - Default App
    let firebaseAI = FirebaseAI.firebaseAI()
    let _ = FirebaseAI.firebaseAI(backend: .googleAI())
    let _ = FirebaseAI.firebaseAI(backend: .vertexAI())
    let _ = FirebaseAI.firebaseAI(backend: .vertexAI(location: "my-location"))

    // Instantiate Firebase AI SDK - Custom App
    let _ = FirebaseAI.firebaseAI(app: app!)
    let _ = FirebaseAI.firebaseAI(app: app!, backend: .googleAI())
    let _ = FirebaseAI.firebaseAI(app: app!, backend: .vertexAI())
    let _ = FirebaseAI.firebaseAI(app: app!, backend: .vertexAI(location: "my-location"))

    // Permutations without optional arguments.

    let _ = firebaseAI.generativeModel(modelName: "gemini-2.0-flash")

    let _ = firebaseAI.generativeModel(
      modelName: "gemini-2.0-flash",
      safetySettings: filters
    )

    let _ = firebaseAI.generativeModel(
      modelName: "gemini-2.0-flash",
      generationConfig: config
    )

    let _ = firebaseAI.generativeModel(
      modelName: "gemini-2.0-flash",
      systemInstruction: systemInstruction
    )

    // All arguments passed.
    let model = firebaseAI.generativeModel(
      modelName: "gemini-2.0-flash",
      generationConfig: config, // Optional
      safetySettings: filters, // Optional
      systemInstruction: systemInstruction, // Optional
      requestOptions: requestOptions // Optional
    )

    // Full Typed Usage
    let pngData = Data() // ....
    let contents = [ModelContent(
      role: "user",
      parts: [
        TextPart("Is it a cat?"),
        InlineDataPart(data: pngData, mimeType: "image/png"),
      ]
    )]

    do {
      let response = try await model.generateContent(contents)
      print(response.text ?? "Couldn't get text... check status")
    } catch {
      print("Error generating content: \(error)")
    }

    // Content input combinations.
    let _ = try await model.generateContent("Constant String")
    let str = "String Variable"
    let _ = try await model.generateContent(str)
    let _ = try await model.generateContent([str])
    let _ = try await model.generateContent(str, "abc", "def")
    let _ = try await model.generateContent(
      str,
      FileDataPart(uri: "gs://test-bucket/image.jpg", mimeType: "image/jpeg")
    )
    #if canImport(UIKit)
      _ = try await model.generateContent(UIImage())
      _ = try await model.generateContent([UIImage()])
      _ = try await model.generateContent([str, UIImage(), TextPart(str)])
      _ = try await model.generateContent(str, UIImage(), "def", UIImage())
      _ = try await model.generateContent([str, UIImage(), "def", UIImage()])
      _ = try await model.generateContent([ModelContent(parts: "def", UIImage()),
                                           ModelContent(parts: "def", UIImage())])
    #elseif canImport(AppKit)
      _ = try await model.generateContent(NSImage())
      _ = try await model.generateContent([NSImage()])
      _ = try await model.generateContent(str, NSImage(), "def", NSImage())
      _ = try await model.generateContent([str, NSImage(), "def", NSImage()])
    #endif

    // PartsRepresentable combinations.
    let _ = ModelContent(parts: [TextPart(str)])
    let _ = ModelContent(role: "model", parts: [TextPart(str)])
    let _ = ModelContent(parts: "Constant String")
    let _ = ModelContent(parts: str)
    let _ = ModelContent(parts: [str])
    let _ = ModelContent(parts: [str, InlineDataPart(data: Data(), mimeType: "foo")])
    #if canImport(UIKit)
      _ = ModelContent(role: "user", parts: UIImage())
      _ = ModelContent(role: "user", parts: [UIImage()])
      _ = ModelContent(parts: [str, UIImage()])
      // Note: without explicitly specifying`: [any PartsRepresentable]` this will fail to compile
      // below with "Cannot convert value of type `[Any]` to expected type `[any Part]`.
      let representable2: [any PartsRepresentable] = [str, UIImage()]
      _ = ModelContent(parts: representable2)
      _ = ModelContent(parts: [str, UIImage(), TextPart(str)])
    #elseif canImport(AppKit)
      _ = ModelContent(role: "user", parts: NSImage())
      _ = ModelContent(role: "user", parts: [NSImage()])
      _ = ModelContent(parts: [str, NSImage()])
      // Note: without explicitly specifying`: [any PartsRepresentable]` this will fail to compile
      // below with "Cannot convert value of type `[Any]` to expected type `[any Part]`.
      let representable2: [any PartsRepresentable] = [str, NSImage()]
      _ = ModelContent(parts: representable2)
      _ = ModelContent(parts: [str, NSImage(), TextPart(str)])
    #endif

    // countTokens API
    let _: CountTokensResponse = try await model.countTokens("What color is the Sky?")
    #if canImport(UIKit)
      let _: CountTokensResponse = try await model.countTokens("What color is the Sky?",
                                                               UIImage())
      let _: CountTokensResponse = try await model.countTokens([
        ModelContent(parts: "What color is the Sky?", UIImage()),
        ModelContent(parts: UIImage(), "What color is the Sky?", UIImage()),
      ])
    #endif

    // Chat
    _ = model.startChat()
    _ = model.startChat(history: [ModelContent(parts: "abc")])
  }

  // Public API tests for GenerateContentResponse.
  func generateContentResponseAPI() {
    let response = GenerateContentResponse(candidates: [])

    let _: [Candidate] = response.candidates
    let _: PromptFeedback? = response.promptFeedback

    // Usage Metadata
    guard let usageMetadata = response.usageMetadata else { fatalError() }
    let _: Int = usageMetadata.promptTokenCount
    let _: Int = usageMetadata.candidatesTokenCount
    let _: Int = usageMetadata.totalTokenCount

    // Computed Properties
    let _: String? = response.text
    let _: [FunctionCallPart] = response.functionCalls
  }
}
