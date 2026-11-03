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

#if canImport(FoundationModels) && compiler(>=6.4) && canImport(CoreImage)
  import CoreGraphics
  import Foundation
  import FoundationModels
  import GeminiAPIClient
  import GeminiTestUtilities
  import Testing
  import Vision

  @testable import GeminiLanguageModel

  /// Integration tests for Vision tools that take an `ImageReference`, which resolve an image in
  /// the transcript by its attachment label.
  ///
  /// The prompts deliberately don't mention the labels, so the tools only work if the model is
  /// shown each label with its image.
  @Suite(
    "Image Reference Tool Integration Tests",
    .requireFoundationModels,
    .tags(.integration)
  )
  struct ImageReferenceToolIntegrationTests {
    /// A Vision tool that reads content from an attached image.
    enum VisionTool: String, CaseIterable, Sendable {
      /// Vision's `BarcodeReaderTool`, which reads QR codes and other barcodes.
      case barcodeReader

      /// Vision's `OCRTool`, which reads text.
      case ocr

      /// The content to put in each attached image, in order.
      var payloads: [String] {
        switch self {
        case .barcodeReader: ["GLM-QR-7F3A9C", "GLM-QR-2B8E41"]
        case .ocr: ["ZEBRA 4821", "MANGO 9370"]
        }
      }

      /// The tool to give the session.
      @available(macOS 27.0, iOS 27.0, visionOS 27.0, *)
      var tool: any Tool {
        switch self {
        case .barcodeReader: BarcodeReaderTool()
        case .ocr: OCRTool()
        }
      }

      /// A short description of the tool and what it reads, for use in prompts.
      var promptDescription: (tool: String, content: String) {
        switch self {
        case .barcodeReader: ("barcode reader tool", "encoded text of the barcode")
        case .ocr: ("text recognition tool", "text")
        }
      }

      /// Creates an image containing the given payload.
      ///
      /// - Parameter payload: The content to put in the image.
      /// - Returns: A QR code or an image of text.
      func image(containing payload: String) throws -> CGImage {
        switch self {
        case .barcodeReader: try TestImages.qrCode(payload)
        case .ocr: try TestImages.text(payload)
        }
      }
    }

    /// A tool and the number of labeled images to attach.
    struct Scenario: Sendable, CustomTestStringConvertible {
      /// The tool to give the session.
      let visionTool: VisionTool

      /// The number of labeled images to attach.
      let imageCount: Int

      /// A short description of the scenario shown in test results.
      var testDescription: String { "\(visionTool.rawValue), \(imageCount) image(s)" }

      /// Every combination of tool and one or two images.
      static let all = VisionTool.allCases.flatMap { visionTool in
        [1, 2].map { Scenario(visionTool: visionTool, imageCount: $0) }
      }
    }

    @Test(
      .requireIntegrationTestingBackend,
      arguments: IntegrationTestingBackend.availableBackends, Scenario.all
    )
    @available(macOS 27.0, iOS 27.0, visionOS 27.0, *)
    func toolResolvesLabeledImagesWithoutLabelsInPrompt(
      backend: IntegrationTestingBackend,
      scenario: Scenario
    ) async throws {
      let visionTool = scenario.visionTool
      let imageCount = scenario.imageCount
      let model = try await backend.makeModel()
      let session = LanguageModelSession(model: model, tools: [visionTool.tool])
      let payloads = Array(visionTool.payloads.prefix(imageCount))
      let labels = ["image-a", "image-b"].prefix(imageCount)
      let images = try payloads.map { try visionTool.image(containing: $0) }
      let (toolName, content) = visionTool.promptDescription
      let prompt =
        imageCount == 1
        ? "Use the \(toolName) on this image. Reply with the exact \(content)."
        : """
        Use the \(toolName) on each of these images. Reply with the exact \(content) of each \
        image, in order.
        """

      let response = try await session.respond {
        prompt
        for (image, label) in zip(images, labels) {
          Attachment(image).label(label)
        }
      }

      var calledLabels: [String] = []
      var toolOutputs: [String] = []
      for entry in session.transcript {
        switch entry {
        case .toolCalls(let toolCalls):
          for call in toolCalls {
            let image = try call.arguments.value(GeneratedContent.self, forProperty: "image")
            calledLabels.append(try image.value(String.self, forProperty: "attachmentLabel"))
          }
        case .toolOutput(let toolOutput):
          toolOutputs.append(toolOutput.segments.map(\.description).joined())
        default:
          break
        }
      }
      #expect(Set(calledLabels) == Set(labels))
      for payload in payloads {
        #expect(toolOutputs.contains { $0.contains(payload) })
        #expect(response.content.localizedCaseInsensitiveContains(payload))
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4) && canImport(CoreImage)
