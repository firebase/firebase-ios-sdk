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

#if compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels)) && !canImport(ImageIO)
  import Foundation
  #if FoundationModelsFake
    import FoundationModelsFake
  #else
    import FoundationModels
  #endif
  import GeminiAPIDataModels
  import GeminiTestUtilities
  import Testing

  @testable import GeminiLanguageModel

  /// Tests for the pass-through image translator used on platforms without ImageIO.
  @Suite("GeminiImageTranslator pass-through Tests", .requireFoundationModels)
  struct GeminiImageTranslatorPassThroughTests {
    /// The start of a PNG file.
    static let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00])

    /// The start of a JPEG file.
    static let jpegBytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])

    /// The start of a WebP file.
    static let webPBytes = Data(
      Array("RIFF".utf8) + [0x24, 0x00, 0x00, 0x00] + Array("WEBPVP8 ".utf8))

    /// The start of a HEIC file.
    static let heicBytes = Data([0x00, 0x00, 0x00, 0x18] + Array("ftypheic".utf8))

    /// A file format and its sample bytes.
    struct FileCase: Sendable, CustomTestStringConvertible {
      /// The file extension.
      let pathExtension: String

      /// The expected MIME type.
      let mimeType: String

      /// The file contents.
      let bytes: Data

      /// The label shown in test results.
      var testDescription: String { pathExtension }
    }

    /// Every format that's passed through without re-encoding.
    static let fileCases: [FileCase] = [
      FileCase(pathExtension: "png", mimeType: "image/png", bytes: pngBytes),
      FileCase(pathExtension: "jpg", mimeType: "image/jpeg", bytes: jpegBytes),
      FileCase(pathExtension: "webp", mimeType: "image/webp", bytes: webPBytes),
      FileCase(pathExtension: "heic", mimeType: "image/heic", bytes: heicBytes),
    ]

    @Test(arguments: fileCases)
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func fileURLIsPassedThrough(_ fileCase: FileCase) throws {
      let url = try Self.temporaryFile(fileCase.bytes, pathExtension: fileCase.pathExtension)
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == fileCase.mimeType)
      #expect(blob.data == fileCase.bytes)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func pngDataURLIsPassedThrough() throws {
      let url = try #require(
        URL(string: "data:image/png;base64,\(Self.pngBytes.base64EncodedString())")
      )
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      let blob = try Self.inlineBlob(GeminiImageTranslator.partData(for: attachment))

      #expect(blob.mimeType == "image/png")
      #expect(blob.data == Self.pngBytes)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func unknownExtensionNeedsReencoding() throws {
      let url = try Self.temporaryFile(Self.pngBytes, pathExtension: "bin")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      #expect(throws: GeminiImageTranslator.TranslationError.reencodingUnavailable) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func unknownExtensionIsRejectedBeforeReadingTheFile() throws {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("bin")
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      #expect(throws: GeminiImageTranslator.TranslationError.reencodingUnavailable) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func rotatedImageNeedsReencoding() throws {
      let url = try Self.temporaryFile(Self.pngBytes, pathExtension: "png")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .right)

      #expect(throws: GeminiImageTranslator.TranslationError.reencodingUnavailable) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func mislabeledFileIsUndecodable() throws {
      let url = try Self.temporaryFile(Data("not an image".utf8), pathExtension: "png")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      #expect(throws: GeminiImageTranslator.TranslationError.undecodableImage) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func videoLabeledAsHEICIsUndecodable() throws {
      let mp4Bytes = Data([0x00, 0x00, 0x00, 0x18] + Array("ftypisom".utf8))
      let url = try Self.temporaryFile(mp4Bytes, pathExtension: "heic")
      defer { try? FileManager.default.removeItem(at: url) }
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      #expect(throws: GeminiImageTranslator.TranslationError.undecodableImage) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    @Test(arguments: [
      "data:text/plain;base64,aGVsbG8="
    ])
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func nonImageDataURLNeedsReencoding(_ string: String) throws {
      let url = try #require(URL(string: string))
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      #expect(throws: GeminiImageTranslator.TranslationError.reencodingUnavailable) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    @Test(arguments: [
      "data:image/png,plain-text",
      "data:;base64,iVBORw0KGgo=",
      "data:base64,iVBORw0KGgo=",
    ])
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func malformedDataURLIsUndecodable(_ string: String) throws {
      let url = try #require(URL(string: string))
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      #expect(throws: GeminiImageTranslator.TranslationError.undecodableImage) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func remoteURLIsUnsupported() throws {
      let url = try #require(URL(string: "https://example.com/image.png"))
      let attachment = Transcript.ImageAttachment(imageURL: url, orientation: .up)

      #expect(throws: GeminiImageTranslator.TranslationError.unsupportedURL(url)) {
        try GeminiImageTranslator.partData(for: attachment)
      }
    }

    // MARK: - Helpers

    /// The MIME type and bytes of inline part data.
    struct InlineBlob {
      /// The MIME type.
      let mimeType: String

      /// The bytes.
      let data: Data
    }

    /// Returns the inline blob in `partData`.
    ///
    /// - Parameter partData: The part data to unwrap.
    /// - Returns: The MIME type and bytes.
    /// - Throws: An error if `partData` isn't inline data.
    private static func inlineBlob(_ partData: Part.PartData) throws -> InlineBlob {
      guard case .inlineData(let blob) = partData else {
        Issue.record("Expected inline data, got \(partData).")
        throw CancellationError()
      }
      return InlineBlob(mimeType: try #require(blob.mimeType), data: try #require(blob.data))
    }

    /// Writes `data` to a new temporary file.
    ///
    /// - Parameters:
    ///   - data: The file contents.
    ///   - pathExtension: The file extension.
    /// - Returns: The file URL.
    /// - Throws: An error if the file can't be written.
    private static func temporaryFile(_ data: Data, pathExtension: String) throws -> URL {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(pathExtension)
      try data.write(to: url)
      return url
    }
  }
#endif
