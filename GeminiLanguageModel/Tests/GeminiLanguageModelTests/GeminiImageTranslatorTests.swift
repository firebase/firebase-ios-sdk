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
  import CoreGraphics
  import Foundation
  import FoundationModels
  import GeminiAPIDataModels
  import GeminiTestUtilities
  import ImageIO
  import Testing
  import UniformTypeIdentifiers

  @testable import GeminiLanguageModel

  @Suite("GeminiImageTranslator Tests", .requireFoundationModels)
  struct GeminiImageTranslatorTests {
    /// The expected result of displaying the standard quadrant image in a given orientation.
    struct OrientationCase: Sendable, CustomTestStringConvertible {
      let orientation: CGImagePropertyOrientation
      let width: Int
      let height: Int
      let topLeft: TestImages.Color
      let topRight: TestImages.Color
      let bottomLeft: TestImages.Color
      let bottomRight: TestImages.Color

      var testDescription: String { "orientation \(orientation.rawValue)" }
    }

    /// Expected display layouts of a 128x64 image with red, green, blue, and yellow quadrants
    /// (top-left, top-right, bottom-left, bottom-right) in each EXIF orientation.
    static let orientationCases: [OrientationCase] = [
      OrientationCase(
        orientation: .up, width: 128, height: 64,
        topLeft: .red, topRight: .green, bottomLeft: .blue, bottomRight: .yellow
      ),
      OrientationCase(
        orientation: .upMirrored, width: 128, height: 64,
        topLeft: .green, topRight: .red, bottomLeft: .yellow, bottomRight: .blue
      ),
      OrientationCase(
        orientation: .down, width: 128, height: 64,
        topLeft: .yellow, topRight: .blue, bottomLeft: .green, bottomRight: .red
      ),
      OrientationCase(
        orientation: .downMirrored, width: 128, height: 64,
        topLeft: .blue, topRight: .yellow, bottomLeft: .red, bottomRight: .green
      ),
      OrientationCase(
        orientation: .leftMirrored, width: 64, height: 128,
        topLeft: .red, topRight: .blue, bottomLeft: .green, bottomRight: .yellow
      ),
      OrientationCase(
        orientation: .right, width: 64, height: 128,
        topLeft: .blue, topRight: .red, bottomLeft: .yellow, bottomRight: .green
      ),
      OrientationCase(
        orientation: .rightMirrored, width: 64, height: 128,
        topLeft: .yellow, topRight: .green, bottomLeft: .blue, bottomRight: .red
      ),
      OrientationCase(
        orientation: .left, width: 64, height: 128,
        topLeft: .green, topRight: .yellow, bottomLeft: .red, bottomRight: .blue
      ),
    ]

    // MARK: - In-memory images

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func cgImageIsReencodedAsJPEG() throws {
      let image = try TestImages.solid(.red, width: 64, height: 32)
      let attachment = Transcript.ImageAttachment(image)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      #expect(TestImages.type(of: blob.data) == .jpeg)
      #expect(TestImages.embeddedOrientation(of: blob.data) == nil)
      let decoded = try TestImages.decode(blob.data)
      #expect(decoded.width == 64)
      #expect(decoded.height == 32)
      #expect(try TestImages.quadrantColors(of: decoded).topLeft == .red)
    }

    @Test(arguments: orientationCases)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func cgImageIsRotatedToDisplayOrientation(_ testCase: OrientationCase) throws {
      let image = try Self.makeQuadrantImage()
      let attachment = Transcript.ImageAttachment(image, orientation: testCase.orientation)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      #expect(TestImages.embeddedOrientation(of: blob.data) == nil)
      try Self.expectDisplayLayout(of: blob.data, matches: testCase)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func transparencyIsCompositedOntoBlack() throws {
      let image = try Self.makeTransparentImage()
      let attachment = Transcript.ImageAttachment(image)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      let decoded = try TestImages.decode(blob.data)
      #expect(try TestImages.quadrantColors(of: decoded).topLeft == .black)
    }

    // MARK: - File URLs

    @Test(
      arguments: [
        (UTType.png, "png", "image/png"),
        (UTType.jpeg, "jpg", "image/jpeg"),
        (UTType.heic, "heic", "image/heic"),
      ]
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func supportedFileIsPassedThroughUnchanged(
      type: UTType,
      pathExtension: String,
      expectedMIMEType: String
    ) throws {
      let fileData = try TestImages.encode(Self.makeQuadrantImage(), as: type)
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: pathExtension)
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == expectedMIMEType)
      #expect(blob.data == fileData)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func passThroughTypeIsDetectedFromContentsNotExtension() throws {
      let fileData = try TestImages.encode(Self.makeQuadrantImage(), as: .png)
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: "jpg")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/png")
      #expect(blob.data == fileData)
    }

    @Test(arguments: [(UTType.tiff, "tiff"), (UTType.gif, "gif"), (UTType.bmp, "bmp")])
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func unsupportedFileFormatIsReencodedAsJPEG(type: UTType, pathExtension: String) throws {
      let fileData = try TestImages.encode(Self.makeQuadrantImage(), as: type)
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: pathExtension)
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      #expect(TestImages.type(of: blob.data) == .jpeg)
      try Self.expectDisplayLayout(of: blob.data, matches: Self.orientationCases[0])
    }

    @Test(arguments: orientationCases.filter { $0.orientation != .up })
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func fileWithEmbeddedOrientationIsRotatedAndReencoded(_ testCase: OrientationCase) throws {
      let fileData = try TestImages.encode(
        Self.makeQuadrantImage(),
        as: .jpeg,
        orientation: testCase.orientation
      )
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: "jpg")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      #expect(blob.data != fileData)
      #expect(TestImages.embeddedOrientation(of: blob.data) == nil)
      try Self.expectDisplayLayout(of: blob.data, matches: testCase)
    }

    @Test(arguments: orientationCases.filter { $0.orientation != .up })
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func rotationMatchesImageIOOrientationTransform(_ testCase: OrientationCase) throws {
      let fileData = try TestImages.encode(
        Self.makeQuadrantImage(),
        as: .png,
        orientation: testCase.orientation
      )
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: "png")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)
      let reference = try Self.imageIOOrientedImage(from: fileData)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      let decoded = try TestImages.decode(blob.data)
      #expect(decoded.width == reference.width)
      #expect(decoded.height == reference.height)
      let colors = try TestImages.quadrantColors(of: decoded)
      let referenceColors = try TestImages.quadrantColors(of: reference)
      #expect(colors.topLeft == referenceColors.topLeft)
      #expect(colors.topRight == referenceColors.topRight)
      #expect(colors.bottomLeft == referenceColors.bottomLeft)
      #expect(colors.bottomRight == referenceColors.bottomRight)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func explicitOrientationOverridesEmbeddedOrientation() throws {
      let fileData = try TestImages.encode(Self.makeQuadrantImage(), as: .jpeg, orientation: .right)
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: "jpg")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      #expect(blob.data != fileData)
      #expect(TestImages.embeddedOrientation(of: blob.data) == nil)
      try Self.expectDisplayLayout(of: blob.data, matches: Self.orientationCases[0])
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func missingFileThrowsUnreadableFile() throws {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("GeminiLanguageModelTests-missing-\(UUID().uuidString).png")
      let attachment = Transcript.ImageAttachment(imageURL: url)

      #expect(throws: GeminiImageTranslator.TranslationError.unreadableFile(url)) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func nonImageFileThrowsUndecodableImage() throws {
      let url = try TestImages.writeTemporaryFile(Data("Not an image".utf8), pathExtension: "png")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      #expect(throws: GeminiImageTranslator.TranslationError.undecodableImage) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    // MARK: - Remote URLs

    @Test(
      arguments: [
        "gs://cloud-samples-data/generative-ai/image/scones.jpg",
        "s3://bucket/image.png",
      ]
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func remoteURLThrowsUnsupportedURL(urlString: String) throws {
      let url = try #require(URL(string: urlString))
      let attachment = Transcript.ImageAttachment(imageURL: url)

      #expect(throws: GeminiImageTranslator.TranslationError.unsupportedURL(url)) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    // MARK: - Helpers

    private static func makeQuadrantImage() throws -> CGImage {
      try TestImages.quadrants(
        topLeft: .red,
        topRight: .green,
        bottomLeft: .blue,
        bottomRight: .yellow,
        width: 128,
        height: 64
      )
    }

    private static func makeTransparentImage() throws -> CGImage {
      let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
      let context = try #require(
        CGContext(
          data: nil,
          width: 32,
          height: 32,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      )
      context.clear(CGRect(x: 0, y: 0, width: 32, height: 32))
      return try #require(context.makeImage())
    }

    /// Returns an image with its embedded orientation applied by ImageIO.
    private static func imageIOOrientedImage(from data: Data) throws -> CGImage {
      let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 128,
      ]
      return try #require(
        CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
      )
    }

    private static func inlineBlob(_ partData: Part.PartData) throws -> Blob {
      guard case .inlineData(let blob) = partData else {
        throw TestImages.ImageError(description: "Expected inline data, got \(partData).")
      }
      return blob
    }

    private static func expectDisplayLayout(
      of data: Data,
      matches testCase: OrientationCase,
      sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
      let decoded = try TestImages.decode(data)
      #expect(decoded.width == testCase.width, sourceLocation: sourceLocation)
      #expect(decoded.height == testCase.height, sourceLocation: sourceLocation)
      let colors = try TestImages.quadrantColors(of: decoded)
      #expect(colors.topLeft == testCase.topLeft, sourceLocation: sourceLocation)
      #expect(colors.topRight == testCase.topRight, sourceLocation: sourceLocation)
      #expect(colors.bottomLeft == testCase.bottomLeft, sourceLocation: sourceLocation)
      #expect(colors.bottomRight == testCase.bottomRight, sourceLocation: sourceLocation)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
