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

#if compiler(>=6.4) && canImport(FoundationModels)
  import CoreGraphics
  import CoreImage
  import FirebaseAILogic
  import FirebaseAITestApp
  import FirebaseCore
  import FoundationModels
  import Testing

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
  struct GetTemperature: FoundationModels.Tool {
    let description = "Returns the current temperature for the specified location."

    @Generable
    struct Location {
      let city: String
    }

    @Generable
    struct Temperature {
      let value: Double
    }

    func call(arguments: Location) async throws -> Temperature {
      return Temperature(value: 25.0)
    }
  }

  @Suite(.serialized)
  struct GeminiLanguageModelTests {
    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testDescribeRedImage(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(name: ModelNames.gemini3_1_FlashLite)
      let session = LanguageModelSession(model: model)

      let cgImage = try makeTestImage()

      let response = try await session.respond {
        "What is the dominant color of this image?"
        Attachment(cgImage)
      }

      let content = response.content
      print(#function + ": " + content)
      #expect(!content.isEmpty)
      #expect(content.lowercased().contains("red"))
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testStreamResponse(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(name: ModelNames.gemini3_1_FlashLite)
      let session = LanguageModelSession(model: model)

      let stream = session.streamResponse {
        "Tell me a story about a magic backpack."
      }

      var text = ""
      for try await snapshot in stream {
        #expect(snapshot.content.hasPrefix(text))
        text = snapshot.content
      }
      let allText = try await stream.collect().content

      #expect(!text.isEmpty)
      #expect(text == allText)
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testGeneratePhoto(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(
        name: ModelNames.gemini3_1_FlashImage,
        options: GeminiGenerationOptions(responseModalities: [.image])
      )

      let session = LanguageModelSession(model: model)
      var generatedImage: Transcript.ImageAttachment?
      let response = try await session
        .respond(
          to: "Generate a photo of the Google I/O 2026 stage with a DJ playing some sweet music on stage."
        )
      for entry in response.transcriptEntries {
        if case let .response(response) = entry {
          for segment in response.segments {
            if case let .attachment(attachment) = segment,
               case let .image(image) = attachment.content {
              generatedImage = image
            }
          }
        }
      }

      let ciImage = try #require(
        generatedImage?.ciImage,
        "Could not find generated photo in response."
      )
      saveGeneratedImage(ciImage, named: "generated-dj-set-io-2026")
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testGeneratePhotoWithImageConfig(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(
        name: ModelNames.gemini3_1_FlashImage,
        options: GeminiGenerationOptions(
          responseModalities: [.image],
          imageConfig: ImageConfig(aspectRatio: .square1x1, imageSize: .size1K)
        )
      )

      let session = LanguageModelSession(model: model)
      var generatedImage: Transcript.ImageAttachment?
      let response = try await session
        .respond(
          to: "Generate a photo of a single red apple on a wooden table."
        )
      for entry in response.transcriptEntries {
        if case let .response(response) = entry {
          for segment in response.segments {
            if case let .attachment(attachment) = segment,
               case let .image(image) = attachment.content {
              generatedImage = image
            }
          }
        }
      }

      let ciImage = try #require(
        generatedImage?.ciImage,
        "Could not find generated photo in response."
      )
      saveGeneratedImage(ciImage, named: "generated-apple-square-1k")
      #expect(ciImage.extent.width == 1024)
      #expect(ciImage.extent.height == 1024)
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testStreamPhoto(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(
        name: ModelNames.gemini3_1_FlashImage,
        options: GeminiGenerationOptions(responseModalities: [.image])
      )
      let session = LanguageModelSession(model: model)

      let stream = session.streamResponse {
        "A kawaii-style sticker of a happy red panda wearing a tiny bamboo hat."
        "It's munching on a green bamboo leaf."
        "The design features bold, clean outlines, simple cel-shading, and a vibrant color palette."
        "The background must be white."
      }

      var generatedImages = [Transcript.ImageAttachment]()
      for try await snapshot in stream {
        for entry in snapshot.transcriptEntries {
          if case let .response(response) = entry {
            for segment in response.segments {
              if case let .attachment(attachmentSegment) = segment,
                 case let .image(imageAttachment) = attachmentSegment.content {
                generatedImages.append(imageAttachment)
              }
            }
          }
        }
      }

      #expect(!generatedImages.isEmpty, "No images were generated.")
      for (index, image) in generatedImages.enumerated() {
        saveGeneratedImage(image.ciImage, named: "panda-sticker-\(index)")
      }
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testGeneratePoemWithThoughts(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(
        name: ModelNames.gemini3_1_FlashLite,
        options: GeminiGenerationOptions(includeThoughts: true)
      )
      let session = LanguageModelSession(model: model)

      let levels: [ContextOptions.ReasoningLevel] = [.light, .moderate, .deep, .custom("minimal")]
      for level in levels {
        let response = try await session.respond(
          to: "Write me a short poem about Swift programming language",
          contextOptions: ContextOptions(reasoningLevel: level)
        )

        let content = response.content
        #expect(!content.isEmpty)

        if level == .deep {
          let reasoningEntries = response.transcriptEntries.compactMap { entry in
            if case let .reasoning(reasoning) = entry { return reasoning }
            return nil
          }
          #expect(!reasoningEntries.isEmpty)
        }
      }
    }

    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    @Generable(description: "Basic profile information about a cat")
    struct CatProfile {
      var name: String

      @Guide(description: "The age of the cat", .range(0 ... 20))
      var age: Int

      @Guide(description: "A one sentence profile about the cat's personality")
      var profile: String
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testGenerateStructuredCat(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(name: ModelNames.gemini3_1_FlashLite)
      let session = LanguageModelSession(model: model)

      let response = try await session.respond(
        to: "Generate a cute rescue cat",
        generating: CatProfile.self
      )

      let cat = response.content
      #expect(!cat.name.isEmpty)
      #expect(cat.age >= 0 && cat.age <= 20)
      #expect(!cat.profile.isEmpty)
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testGenerationOptionsMapping(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(name: ModelNames.gemini3_1_FlashLite)
      let session = LanguageModelSession(model: model)

      let response = try await session.respond(
        to: "Write a short poem about Swift.",
        options: GenerationOptions(
          samplingMode: .random(top: 40, seed: 12345),
          temperature: 0.7,
          maximumResponseTokens: 256
        )
      )

      let content = response.content
      #expect(!content.isEmpty)

      let usage = response.usage
      #expect(usage.input.totalTokenCount > 0)
      #expect(usage.output.totalTokenCount > 0)
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testToolCalling(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(name: ModelNames.gemini3_1_FlashLite)
      let session = LanguageModelSession(model: model, tools: [GetTemperature()])

      let response = try await session.respond(to: "What is the temperature in San Francisco?")
      let content = response.content
      #expect(!content.isEmpty)
      #expect(content.contains("25"))
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testToolCallingDisallowed(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(name: ModelNames.gemini3_1_FlashLite)
      let session = LanguageModelSession(model: model, tools: [GetTemperature()])

      let response = try await session.respond(
        to: "What is the temperature in San Francisco?",
        options: GenerationOptions(
          toolCallingMode: .disallowed
        )
      )
      let content = response.content
      #expect(!content.isEmpty)
      #expect(!content.contains("25"))
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testGoogleMapsGrounding(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(
        name: ModelNames.gemini3_1_FlashLite,
        serverTools: [.googleMaps()]
      )
      let session = LanguageModelSession(model: model)

      let response = try await session
        .respond(to: "Where is a good place to grab a coffee near Alameda, CA?")

      var foundGrounding = false
      for entry in response.transcriptEntries {
        if case let .response(responseEntry) = entry {
          if let groundingMetadata = responseEntry
            .metadata["groundingMetadata"] as? GroundingMetadata {
            foundGrounding = true
            let mapChunks = groundingMetadata.groundingChunks.compactMap { $0.maps }
            #expect(!mapChunks.isEmpty)
            for mapsChunk in mapChunks {
              #expect(mapsChunk.url != nil)
              let title = try #require(mapsChunk.title)
              #expect(!title.isEmpty)
              let placeID = try #require(mapsChunk.placeID)
              #expect(!placeID.isEmpty)
            }
          }
        }
      }
      #expect(foundGrounding)
    }

    @Test(arguments: InstanceConfig.defaultConfigs)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    func testGoogleSearchGrounding(_ config: InstanceConfig) async throws {
      let ai = FirebaseAI.componentInstance(config)
      let model = ai.geminiLanguageModel(
        name: ModelNames.gemini3_1_FlashLite,
        serverTools: [.googleSearch()]
      )
      let session = LanguageModelSession(model: model)
      let response = try await session.respond(to: "What is the weather in Toronto today?")

      var foundGrounding = false
      for entry in response.transcriptEntries {
        if case let .response(responseEntry) = entry {
          if let groundingMetadata = responseEntry
            .metadata["groundingMetadata"] as? GroundingMetadata {
            foundGrounding = true
            let searchEntrypoint = try #require(groundingMetadata.searchEntryPoint)
            #expect(!groundingMetadata.webSearchQueries.isEmpty)
            #expect(!searchEntrypoint.renderedContent.isEmpty)
            #expect(!groundingMetadata.groundingChunks.isEmpty)
            #expect(!groundingMetadata.groundingSupports.isEmpty)

            for chunk in groundingMetadata.groundingChunks {
              #expect(chunk.web != nil)
              let webChunk = try #require(chunk.web)
              #expect(webChunk.uri != nil)
              let title = try #require(webChunk.title)
              #expect(!title.isEmpty)
            }
          }
        }
      }
      #expect(foundGrounding)
    }

    private func makeTestImage() throws -> CGImage {
      let width = 100
      let height = 100
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
      guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
      ) else {
        struct CGContextError: Error {}
        throw CGContextError()
      }

      context.setFillColor(CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0))
      context.fill(CGRect(x: 0, y: 0, width: width, height: height))
      guard let cgImage = context.makeImage() else {
        struct CGImageError: Error {}
        throw CGImageError()
      }
      return cgImage
    }

    func saveGeneratedImage(_ ciImage: CIImage, named filename: String) {
      let context = CIContext(options: nil)

      // Convert to target destination path
      let temporaryDirectory = FileManager.default.temporaryDirectory
      let fileURL = temporaryDirectory.appendingPathComponent("\(filename).png")

      do {
        // Write the processed pixel data directly to a PNG file
        try context.writePNGRepresentation(
          of: ciImage,
          to: fileURL,
          format: .RGBA8,
          colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        print("🖼️ Visualized image saved to: \(fileURL.path)")
      } catch {
        print("Failed to save visualization: \(error)")
      }
    }
  }
#endif
