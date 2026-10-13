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

#if canImport(FoundationModels) && compiler(>=6.4)
  import Foundation
  import FoundationModels
  import GeminiAPIClient
  import GeminiTestUtilities
  import ImageIO
  import Testing
  import UniformTypeIdentifiers

  @testable import GeminiLanguageModel

  /// Integration tests for image input (`vision`) using `GeminiLanguageModel`.
  ///
  /// These tests use the default sampling mode, since many Gemini 3 models don't support greedy
  /// sampling. To keep responses deterministic, the images are simple, high-contrast, and generated
  /// in code, and the prompts tightly constrain the format of the answer.
  @Suite(
    "Image Understanding Integration Tests",
    .requireFoundationModels,
    .tags(.integration)
  )
  struct ImageUnderstandingIntegrationTests {
    /// The instruction appended to prompts that expect a single color name.
    static let oneColorWordFormat =
      "Respond with exactly one lowercase English word and no punctuation."

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithImage(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)
      let image = try TestImages.solid(.red)

      let response = try await session.respond {
        Attachment(image)
        "Name the color that fills this entire image. \(Self.oneColorWordFormat)"
      }

      #expect(response.content.localizedCaseInsensitiveContains("red"))
      #expect(response.usage.input.totalTokenCount > 0)
      #expect(response.usage.output.totalTokenCount > 0)
    }

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondComparingTwoImages(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)
      let firstImage = try TestImages.solid(.red)
      let secondImage = try TestImages.solid(.blue)

      let response = try await session.respond {
        """
        Each of the following two images is filled with a single color. Respond with exactly two \
        lowercase English words separated by a single space and no punctuation: the color of the \
        first image, then the color of the second image.
        """
        Attachment(firstImage)
        Attachment(secondImage)
      }

      let words = response.content.lowercased().split(whereSeparator: { !$0.isLetter })
      #expect(words == ["red", "blue"])
    }

    @Generable(description: "The shape shown in an image")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    enum ShapeLabel: String {
      case circle
      case square
      case triangle
    }

    // A top-level enum isn't used directly because top-level enum guided generation currently
    // fails to decode Gemini's JSON-quoted string, independent of image input.
    @Generable(description: "The classification of the shape shown in an image")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct ShapeClassification {
      var shape: ShapeLabel
    }

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends, TestImages.Shape.allCases
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondClassifyingImage(
      backend: IntegrationTestingBackend,
      shape: TestImages.Shape
    ) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)
      let image = try TestImages.shape(shape)

      let response = try await session.respond(generating: ShapeClassification.self) {
        """
        The following image shows exactly one large black geometric shape on a white background. \
        Choose the label that names that shape: circle, square, or triangle.
        """
        Attachment(image)
      }

      #expect(response.content.shape.rawValue == shape.rawValue)
    }

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondAppliesImageOrientation(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)
      // Stored with red on top; displaying it in the `.down` orientation puts blue on top.
      let image = try TestImages.halves(top: .red, bottom: .blue)

      let response = try await session.respond {
        Attachment(image, orientation: .down)
        """
        This image is split into a top half and a bottom half, each filled with a single color. \
        Name the color of the top half. \(Self.oneColorWordFormat)
        """
      }

      #expect(response.content.localizedCaseInsensitiveContains("blue"))
      #expect(!response.content.localizedCaseInsensitiveContains("red"))
    }

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondWithImageFileURL(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)
      let fileData = try TestImages.encode(TestImages.solid(.green), as: .png)
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: "png")
      defer { try? FileManager.default.removeItem(at: url) }

      let response = try await session.respond {
        Attachment(imageURL: url)
        "Name the color that fills this entire image. \(Self.oneColorWordFormat)"
      }

      #expect(response.content.localizedCaseInsensitiveContains("green"))
    }

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionStreamResponseWithImage(backend: IntegrationTestingBackend) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)
      let image = try TestImages.solid(.yellow)

      let stream = session.streamResponse {
        Attachment(image)
        "Name the color that fills this entire image. \(Self.oneColorWordFormat)"
      }
      var snapshotCount = 0
      for try await _ in stream {
        snapshotCount += 1
      }
      let response = try await stream.collect()

      #expect(snapshotCount > 0)
      #expect(response.content.localizedCaseInsensitiveContains("yellow"))
    }

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func sessionRespondMultiTurnWithImageInHistory(
      backend: IntegrationTestingBackend
    ) async throws {
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model)
      let image = try TestImages.solid(.blue)

      _ = try await session.respond {
        Attachment(image)
        "Remember this image for my next question. Respond with exactly the word OK."
      }
      let response = try await session.respond(
        to: """
          Name the color that fills the entire image I sent in my previous message. \
          \(Self.oneColorWordFormat)
          """
      )

      #expect(response.content.localizedCaseInsensitiveContains("blue"))
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
