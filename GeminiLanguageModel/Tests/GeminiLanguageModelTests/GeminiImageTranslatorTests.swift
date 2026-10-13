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
  import CoreVideo
  import Foundation
  import FoundationModels
  import GeminiAPIDataModels
  import GeminiTestUtilities
  import ImageIO
  import Testing
  import UniformTypeIdentifiers

  #if canImport(CoreImage)
    import CoreImage
  #endif  // canImport(CoreImage)

  @testable import GeminiLanguageModel

  @Suite("GeminiImageTranslator Tests", .requireFoundationModels)
  struct GeminiImageTranslatorTests {
    /// The expected result of displaying the standard quadrant image in a given orientation.
    struct OrientationCase: Sendable, CustomTestStringConvertible {
      /// The display orientation applied to the standard quadrant image.
      let orientation: CGImagePropertyOrientation

      /// The expected width of the displayed image, in pixels.
      let width: Int

      /// The expected height of the displayed image, in pixels.
      let height: Int

      /// The expected color of the displayed image's top-left quadrant.
      let topLeft: TestImages.Color

      /// The expected color of the displayed image's top-right quadrant.
      let topRight: TestImages.Color

      /// The expected color of the displayed image's bottom-left quadrant.
      let bottomLeft: TestImages.Color

      /// The expected color of the displayed image's bottom-right quadrant.
      let bottomRight: TestImages.Color

      /// A short description of the case shown in test results.
      var testDescription: String { "orientation \(orientation.rawValue)" }
    }

    /// An image file format used as a test fixture.
    struct FileFormat: Sendable, CustomTestStringConvertible {
      /// The image type.
      let type: UTType

      /// The file extension for fixture files.
      let pathExtension: String

      /// The MIME type Gemini expects for the format.
      let mimeType: String

      /// A short description of the format shown in test results.
      var testDescription: String { type.identifier }
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

    /// The expected layout of the standard quadrant image when displayed upright.
    static let uprightCase = orientationCases[0]

    /// The orientation cases that require rotating or flipping the image.
    static let rotatedOrientationCases = orientationCases.filter { $0.orientation != .up }

    /// Formats that can be sent without re-encoding and can be encoded on this platform.
    static let passThroughFormats = [
      FileFormat(type: .png, pathExtension: "png", mimeType: "image/png"),
      FileFormat(type: .jpeg, pathExtension: "jpg", mimeType: "image/jpeg"),
      FileFormat(type: .heic, pathExtension: "heic", mimeType: "image/heic"),
    ].filter { TestImages.canEncode($0.type) }

    /// Formats that must be re-encoded and can be encoded on this platform.
    static let reencodedFormats = [
      FileFormat(type: .tiff, pathExtension: "tiff", mimeType: "image/tiff"),
      FileFormat(type: .gif, pathExtension: "gif", mimeType: "image/gif"),
      FileFormat(type: .bmp, pathExtension: "bmp", mimeType: "image/bmp"),
    ].filter { TestImages.canEncode($0.type) }

    /// Formats with embedded orientation metadata that can be encoded on this platform.
    static let orientableFormats = [
      FileFormat(type: .jpeg, pathExtension: "jpg", mimeType: "image/jpeg"),
      FileFormat(type: .heic, pathExtension: "heic", mimeType: "image/heic"),
    ].filter { TestImages.canEncode($0.type) }

    /// Color spaces that can't be represented in an 8-bit JPEG.
    static let extendedRangeAndHDRColorSpaceNames: [String] = [
      CGColorSpace.extendedSRGB,
      CGColorSpace.extendedLinearSRGB,
      CGColorSpace.extendedDisplayP3,
      CGColorSpace.itur_2100_PQ,
      CGColorSpace.itur_2100_HLG,
      CGColorSpace.displayP3_PQ,
    ].map { $0 as String }

    // MARK: - In-Memory Images

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

    @Test(arguments: orientationCases.filter { [.up, .right].contains($0.orientation) })
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func pixelBufferIsRotatedAndReencodedAsJPEG(_ testCase: OrientationCase) throws {
      let pixelBuffer = try TestImages.pixelBuffer(from: Self.makeQuadrantImage())
      let attachment = Transcript.ImageAttachment(pixelBuffer, orientation: testCase.orientation)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      #expect(TestImages.embeddedOrientation(of: blob.data) == nil)
      try Self.expectDisplayLayout(of: blob.data, matches: testCase)
    }

    @Test(arguments: extendedRangeAndHDRColorSpaceNames)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func extendedRangeAndHDRImagesAreConvertedToSRGB(colorSpaceName: String) throws {
      let image = try TestImages.redraw(
        Self.makeQuadrantImage(),
        inColorSpaceNamed: colorSpaceName as CFString
      )
      let attachment = Transcript.ImageAttachment(image)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      let decoded = try TestImages.decode(blob.data)
      #expect(decoded.colorSpace?.name == CGColorSpace.sRGB)
      try Self.expectDisplayLayout(of: blob.data, matches: Self.uprightCase)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func standardRangeColorSpaceIsPreserved() throws {
      let image = try TestImages.redraw(
        Self.makeQuadrantImage(),
        inColorSpaceNamed: CGColorSpace.displayP3
      )
      let attachment = Transcript.ImageAttachment(image)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      let decoded = try TestImages.decode(blob.data)
      #expect(decoded.colorSpace?.name == CGColorSpace.displayP3)
      try Self.expectDisplayLayout(of: blob.data, matches: Self.uprightCase)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func transparencyIsCompositedOntoBlack() throws {
      let image = try TestImages.transparentWhite()
      let attachment = Transcript.ImageAttachment(image)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      let decoded = try TestImages.decode(blob.data)
      #expect(try TestImages.quadrantColors(of: decoded).topLeft == .black)
    }

    #if canImport(CoreImage)
      @Test(arguments: orientationCases.filter { [.up, .right].contains($0.orientation) })
      @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
      func ciImageIsRotatedAndReencodedAsJPEG(_ testCase: OrientationCase) throws {
        let ciImage = CIImage(cgImage: try Self.makeQuadrantImage())
        let attachment = Transcript.ImageAttachment(ciImage, orientation: testCase.orientation)

        let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

        #expect(blob.mimeType == "image/jpeg")
        #expect(TestImages.embeddedOrientation(of: blob.data) == nil)
        try Self.expectDisplayLayout(of: blob.data, matches: testCase)
      }

      @Test(arguments: ["empty", "infinite"])
      @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
      func unrenderableCIImageThrowsUndecodableImage(extent: String) throws {
        // Reading `cgImage` for these attachments traps, so they must be rejected beforehand.
        let ciImage =
          extent == "empty" ? CIImage.empty() : CIImage(color: CIColor(red: 1, green: 0, blue: 0))
        let attachment = Transcript.ImageAttachment(ciImage)

        #expect(throws: GeminiImageTranslator.TranslationError.undecodableImage) {
          try GeminiImageTranslator.partData(for: attachment)
        }
      }
    #endif  // canImport(CoreImage)

    // MARK: - File URLs

    @Test(arguments: passThroughFormats)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func supportedFileIsPassedThroughUnchanged(format: FileFormat) throws {
      let fileData = try TestImages.encode(Self.makeQuadrantImage(), as: format.type)
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: format.pathExtension)
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == format.mimeType)
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

    @Test(arguments: reencodedFormats)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func unsupportedFileFormatIsReencodedAsJPEG(format: FileFormat) throws {
      let fileData = try TestImages.encode(Self.makeQuadrantImage(), as: format.type)
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: format.pathExtension)
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      #expect(TestImages.type(of: blob.data) == .jpeg)
      try Self.expectDisplayLayout(of: blob.data, matches: Self.uprightCase)
    }

    @Test(arguments: rotatedOrientationCases, orientableFormats)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func fileWithEmbeddedOrientationIsRotatedAndReencoded(
      _ testCase: OrientationCase,
      format: FileFormat
    ) throws {
      let fileData = try TestImages.encode(
        Self.makeQuadrantImage(),
        as: format.type,
        orientation: testCase.orientation
      )
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: format.pathExtension)
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      #expect(blob.data != fileData)
      #expect(TestImages.embeddedOrientation(of: blob.data) == nil)
      try Self.expectDisplayLayout(of: blob.data, matches: testCase)
    }

    @Test(arguments: rotatedOrientationCases)
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
      try Self.expectDisplayLayout(of: blob.data, matches: Self.uprightCase)
    }

    @Test(.enabled(if: TestImages.canEncode(.heic)))
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func firstImageIsUsedWhenPrimaryImageIsNotFirst() throws {
      let fileData = try TestImages.encode(
        [
          TestImages.Frame(image: Self.makeQuadrantImage()),
          TestImages.Frame(image: TestImages.solid(.white), orientation: .right, isPrimary: true),
        ],
        as: .heic
      )
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: "heic")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      // The file isn't passed through, since Gemini would decode the primary image instead.
      #expect(blob.mimeType == "image/jpeg")
      try Self.expectDisplayLayout(of: blob.data, matches: Self.uprightCase)
    }

    @Test(.enabled(if: TestImages.canEncode(.heic)))
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func firstImageOrientationIsAppliedWhenPrimaryImageIsNotFirst() throws {
      let rightCase = try #require(Self.orientationCases.first { $0.orientation == .right })
      let fileData = try TestImages.encode(
        [
          TestImages.Frame(image: Self.makeQuadrantImage(), orientation: .right),
          TestImages.Frame(image: TestImages.solid(.white), isPrimary: true),
        ],
        as: .heic
      )
      let url = try TestImages.writeTemporaryFile(fileData, pathExtension: "heic")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/jpeg")
      try Self.expectDisplayLayout(of: blob.data, matches: rightCase)
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

    // MARK: - Non-File URLs

    @Test(
      arguments: [
        "gs://cloud-samples-data/generative-ai/image/scones.jpg",
        "s3://bucket/image.png",
      ]
    )
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func nonFileURLThrowsUnsupportedURL(urlString: String) throws {
      let url = try #require(URL(string: urlString))
      let attachment = Transcript.ImageAttachment(imageURL: url)

      #expect(throws: GeminiImageTranslator.TranslationError.unsupportedURL(url)) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func unsupportedURLDescriptionIncludesSchemeButNotURL() throws {
      let url = try #require(URL(string: "https://example.com/image.png?token=secret"))
      let error = GeminiImageTranslator.TranslationError.unsupportedURL(url)

      let description = error.description

      #expect(description.contains("\"https\""))
      #expect(!description.contains("example.com"))
      #expect(!description.contains("secret"))
    }

    // MARK: - Helpers

    /// Creates the standard 128x64 test image with red, green, blue, and yellow quadrants.
    ///
    /// - Returns: The quadrant image, in its upright orientation.
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

    /// Returns an image with its embedded orientation applied by ImageIO.
    ///
    /// - Parameter data: Encoded image data with an embedded orientation.
    /// - Returns: The image in its display orientation, as rendered by ImageIO.
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

    /// Returns the blob from inline part data.
    ///
    /// - Parameter partData: The translated part data.
    /// - Returns: The inline data blob.
    /// - Throws: An error if `partData` isn't inline data.
    private static func inlineBlob(_ partData: Part.PartData) throws -> Blob {
      guard case .inlineData(let blob) = partData else {
        throw TestImages.ImageError(description: "Expected inline data, got \(partData).")
      }
      return blob
    }

    /// Records issues unless encoded image data has the expected size and quadrant colors.
    ///
    /// - Parameters:
    ///   - data: The encoded image data to check.
    ///   - testCase: The expected size and quadrant colors.
    ///   - sourceLocation: The source location to attribute issues to.
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
