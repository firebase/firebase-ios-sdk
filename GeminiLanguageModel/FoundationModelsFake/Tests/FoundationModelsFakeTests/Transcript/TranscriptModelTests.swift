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

#if compiler(>=6.4)
  import Foundation
  import Testing

  @testable import FoundationModelsFake

  #if canImport(CoreGraphics)
    import CoreGraphics
  #endif
  #if canImport(ImageIO)
    import ImageIO
  #endif

  @Suite("Transcript model")
  struct TranscriptModelTests {
    /// Returns a text entry for collection tests.
    ///
    /// - Parameter id: The id of the response and its segment.
    /// - Returns: A response entry with one text segment.
    static func entry(_ id: String) -> Transcript.Entry {
      .response(
        Transcript.Response(id: id, segments: [.text(Transcript.TextSegment(id: id, content: id))])
      )
    }

    // MARK: - Collection conformances

    @Test
    func transcriptIsARandomAccessCollectionOfEntries() {
      let transcript = Transcript(entries: ["a", "b", "c"].map(Self.entry))

      let ids = transcript.map(\.id)

      #expect(ids == ["a", "b", "c"])
      #expect(transcript.startIndex == 0)
      #expect(transcript.endIndex == 3)
      #expect(transcript.count == 3)
      #expect(transcript.last?.id == "c")
      #expect(transcript[1...].map(\.id) == ["b", "c"])
    }

    @Test
    func transcriptIsMutableAndRangeReplaceable() {
      var transcript = Transcript()

      transcript.append(Self.entry("a"))
      transcript.append(contentsOf: [Self.entry("b"), Self.entry("c")])
      transcript[0] = Self.entry("z")
      transcript.insert(Self.entry("y"), at: 1)
      transcript.remove(at: 2)
      transcript.replaceSubrange(0..<1, with: [Self.entry("x"), Self.entry("w")])

      #expect(transcript.map(\.id) == ["x", "w", "y", "c"])
      #expect(transcript.entries.map(\.id) == ["x", "w", "y", "c"])
    }

    @Test
    func emptyTranscriptsAreEqual() {
      let empty = Transcript()

      let seeded = Transcript(entries: [])

      #expect(empty == seeded)
      #expect(empty.isEmpty)
    }

    @Test
    func toolCallsIsARandomAccessCollection() {
      let calls = ["a", "b"].map {
        Transcript.ToolCall(id: $0, toolName: "tool", arguments: GeneratedContent($0))
      }

      let toolCalls = Transcript.ToolCalls(id: "calls", calls)

      #expect(toolCalls.map(\.id) == ["a", "b"])
      #expect(toolCalls.startIndex == 0)
      #expect(toolCalls.endIndex == 2)
      #expect(toolCalls[1].id == "b")
      #expect(Transcript.Entry.toolCalls(toolCalls).id == "calls")
    }

    // MARK: - Identity and equality

    @Test
    func entryAndSegmentIDsComeFromTheirPayloads() throws {
      let segments: [Transcript.Segment] = [
        .text(Transcript.TextSegment(id: "t", content: "text")),
        .structure(
          Transcript.StructuredSegment(id: "s", schemaName: "S", content: GeneratedContent(1))),
        .attachment(
          Transcript.AttachmentSegment(
            id: "a",
            content: .image(Transcript.ImageAttachment(imageURL: try Self.dataURL()))
          )
        ),
      ]

      let ids = segments.map(\.id)

      #expect(ids == ["t", "s", "a"])
    }

    @Test
    func segmentsOfDifferentKindsAreUnequal() {
      let text = Transcript.Segment.text(Transcript.TextSegment(id: "x", content: "1"))

      let structure = Transcript.Segment.structure(
        Transcript.StructuredSegment(id: "x", schemaName: "Int", content: GeneratedContent(1))
      )

      #expect(text != structure)
      #expect(text == .text(Transcript.TextSegment(id: "x", content: "1")))
    }

    @Test
    func promptEqualityComparesEveryProperty() {
      let base = Transcript.Prompt(id: "p", segments: [])

      var changedMetadata = base
      changedMetadata.metadata = ["key": GeneratedContent("value")]
      var changedOptions = base
      changedOptions.options = GenerationOptions(temperature: 0.5)
      var changedContext = base
      changedContext.contextOptions = ContextOptions(reasoningLevel: .deep)
      var changedFormat = base
      changedFormat.responseFormat = Transcript.ResponseFormat(type: String.self)

      #expect(base == Transcript.Prompt(id: "p", segments: []))
      #expect(base != changedMetadata)
      #expect(base != changedOptions)
      #expect(base != changedContext)
      #expect(base != changedFormat)
    }

    @Test
    func responseFormatFromTypeEqualsFormatFromItsSchema() {
      let fromType = Transcript.ResponseFormat(type: String.self)

      let fromSchema = Transcript.ResponseFormat(schema: String.generationSchema)

      #expect(fromType == fromSchema)
      #expect(fromType.kind == fromSchema.kind)
      #expect(fromType != Transcript.ResponseFormat(type: Int.self))
    }

    @Test
    func toolCallEqualityComparesArgumentsAndMetadata() throws {
      let arguments = GeneratedContent(properties: ["city": "Paris"])
      let call = Transcript.ToolCall(id: "c", toolName: "weather", arguments: arguments)

      let withMetadata = Transcript.ToolCall(
        id: "c",
        metadata: ["signature": "abc"],
        toolName: "weather",
        arguments: arguments
      )
      let parsedArguments = Transcript.ToolCall(
        id: "c",
        toolName: "weather",
        arguments: try GeneratedContent(json: #"{"city": "Paris"}"#)
      )

      #expect(call == Transcript.ToolCall(id: "c", toolName: "weather", arguments: arguments))
      #expect(call != withMetadata)
      #expect(withMetadata.metadata["signature"] == GeneratedContent("abc"))
      #expect(call != parsedArguments)
    }

    @Test
    func toolDefinitionsCompareTheirSchemas() {
      let definition = Transcript.ToolDefinition(
        name: "echo",
        description: "Echoes",
        parameters: String.generationSchema
      )

      let other = Transcript.ToolDefinition(
        name: "echo",
        description: "Echoes",
        parameters: Int.generationSchema
      )

      #expect(definition == definition)
      #expect(definition != other)
      #expect(definition.description == "Echoes")
    }

    // MARK: - Response and reasoning

    @Test
    func responseWithAssetIDsMirrorsThemIntoMetadata() {
      let response = Transcript.Response(id: "r", assetIDs: ["a", "b"], segments: [])

      let metadata = response.metadata

      #expect(response.assetIDs == ["a", "b"])
      #expect(metadata == ["assetIDs": GeneratedContent(["a", "b"])])
    }

    @Test
    func responseWithMetadataHasNoAssetIDs() {
      let response = Transcript.Response(id: "r", metadata: ["tokens": 12], segments: [])

      let metadata = response.metadata

      #expect(response.assetIDs.isEmpty)
      #expect(metadata == ["tokens": GeneratedContent(12)])
      #expect(response != Transcript.Response(id: "r", segments: []))
    }

    @Test
    func reasoningEqualityComparesSignatureAndMetadata() {
      let reasoning = Transcript.Reasoning(id: "r", segments: [], signature: Data([1]))

      let otherSignature = Transcript.Reasoning(id: "r", segments: [], signature: Data([2]))
      let otherMetadata = Transcript.Reasoning(
        id: "r",
        metadata: ["k": "v"],
        segments: [],
        signature: Data([1])
      )

      #expect(reasoning == Transcript.Reasoning(id: "r", segments: [], signature: Data([1])))
      #expect(reasoning != otherSignature)
      #expect(reasoning != otherMetadata)
    }

    // MARK: - Images

    /// Returns a small `data:` URL.
    static func dataURL() throws -> URL {
      try #require(URL(string: "data:image/png;base64,iVBORw0KGgo="))
    }

    @Test
    func imageAttachmentKeepsURLAndOrientation() throws {
      let url = try Self.dataURL()

      let image = Transcript.ImageAttachment(imageURL: url, orientation: .right)

      #expect(image.url == url)
      #expect(image.orientation == .right)
      #expect(Transcript.ImageAttachment(imageURL: url).orientation == .up)
    }

    @Test
    func imageAttachmentsAreEqualOnlyToCopies() throws {
      let url = try Self.dataURL()
      let image = Transcript.ImageAttachment(imageURL: url)

      let copy = image
      let sameURL = Transcript.ImageAttachment(imageURL: url)

      #expect(image == copy)
      #expect(image != sameURL)
      #expect(Transcript.Attachment.image(image) == .image(copy))
    }

    @Test
    func fileImagesEncodeAsDataURLsWithSniffedMIMEType() throws {
      let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x01])
      let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("transcript-\(UUID().uuidString).png")
      try png.write(to: fileURL)
      defer { try? FileManager.default.removeItem(at: fileURL) }
      let transcript = Self.transcript(withImageURL: fileURL, label: "photo")

      let attachment = try Self.encodedAttachment(of: transcript)

      #expect(attachment["type"] as? String == "image")
      #expect(attachment["label"] as? String == "photo")
      #expect(attachment["data"] as? String == "data:image/png;base64,\(png.base64EncodedString())")
    }

    @Test
    func dataAndRemoteImageURLsEncodeVerbatim() throws {
      let urls = [
        try Self.dataURL(),
        try #require(URL(string: "https://example.com/image.jpg")),
      ]

      let encoded = try urls.map {
        try Self.encodedAttachment(of: Self.transcript(withImageURL: $0, label: nil))
      }

      #expect(encoded.map { $0["data"] as? String } == urls.map(\.absoluteString))
      #expect(encoded.allSatisfy { $0["label"] == nil })
    }

    @Test(arguments: [
      "data:image/png;base64,iVBORw0KGgo=",
      "https://example.com/image.jpg",
      "gs://bucket/image.jpg",
      "image.jpg",
    ])
    func decodesNonFileImageURLs(urlString: String) throws {
      let url = try #require(URL(string: urlString))
      let json = try JSONEncoder().encode(Self.transcript(withImageURL: url, label: nil))

      let decoded = try JSONDecoder().decode(Transcript.self, from: json)

      #expect(Self.imageURL(in: decoded) == url)
    }

    @Test(arguments: ["file:///etc/hosts", "FILE:///etc/hosts"])
    func rejectsDecodingFileImageURLs(urlString: String) throws {
      let placeholderURL = "https://example.com/placeholder.jpg"
      let url = try #require(URL(string: placeholderURL))
      let encoder = JSONEncoder()
      encoder.outputFormatting = .withoutEscapingSlashes
      let encoded = try encoder.encode(Self.transcript(withImageURL: url, label: nil))
      let json = String(decoding: encoded, as: UTF8.self).replacing(placeholderURL, with: urlString)

      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(Transcript.self, from: Data(json.utf8))
      }
    }

    /// Image signatures and the MIME types sniffed from them.
    static let imageSignatures: [([UInt8], String)] = {
      let webP: [UInt8] = Array("RIFF".utf8) + [0, 0, 0, 0] + Array("WEBP".utf8)
      let heic: [UInt8] = [0, 0, 0, 0x18] + Array("ftypheic".utf8)
      return [
        ([0xFF, 0xD8, 0xFF, 0xE0], "image/jpeg"),
        (Array("GIF89a".utf8), "image/gif"),
        (webP, "image/webp"),
        (heic, "image/heic"),
        ([0x49, 0x49, 0x2A, 0x00], "image/tiff"),
        ([0x00, 0x01], "application/octet-stream"),
      ]
    }()

    @Test(arguments: imageSignatures)
    func sniffsImageMIMETypes(bytes: [UInt8], mimeType: String) {
      let sniffed = ImageAttachmentStorage.mimeType(sniffing: Data(bytes))

      #expect(sniffed == mimeType)
    }

    @Test
    func decodesPercentEncodedDataURLs() {
      let payload = ImageAttachmentStorage.dataURLPayload("data:text/plain,a%20b")

      #expect(payload == Data("a b".utf8))
    }

    #if canImport(CoreGraphics) && canImport(ImageIO)
      @Test
      func cgImageAttachmentsEncodeAsJPEGDataURLs() throws {
        let image = Transcript.ImageAttachment(ImageAttachmentStorage.placeholderImage)
        let transcript = Transcript(entries: [
          .prompt(
            Transcript.Prompt(
              id: "p",
              segments: [.attachment(Transcript.AttachmentSegment(id: "a", content: .image(image)))]
            )
          )
        ])

        let attachment = try Self.encodedAttachment(of: transcript)

        #expect((attachment["data"] as? String)?.hasPrefix("data:image/jpeg;base64,/9j/") == true)
        #expect(image.url == nil)
      }
    #endif

    /// Returns a transcript with one prompt that holds one image.
    ///
    /// - Parameters:
    ///   - url: The image URL.
    ///   - label: The attachment label.
    /// - Returns: The transcript.
    static func transcript(withImageURL url: URL, label: String?) -> Transcript {
      Transcript(entries: [
        .prompt(
          Transcript.Prompt(
            id: "p",
            segments: [
              .attachment(
                Transcript.AttachmentSegment(
                  id: "a",
                  content: .image(Transcript.ImageAttachment(imageURL: url)),
                  label: label
                )
              )
            ]
          )
        )
      ])
    }

    /// Returns the URL of the image in the first prompt segment of a transcript.
    ///
    /// - Parameter transcript: A transcript whose first entry is a prompt with an image.
    /// - Returns: The image's URL, or `nil` if there's no URL-backed image.
    static func imageURL(in transcript: Transcript) -> URL? {
      guard case .prompt(let prompt) = transcript.first,
        case .attachment(let segment) = prompt.segments.first,
        case .image(let image) = segment.content
      else {
        return nil
      }
      return image.url
    }

    /// Encodes a transcript and returns the `attachment` object of its first prompt segment.
    ///
    /// - Parameter transcript: A transcript whose first entry is a prompt with an attachment.
    /// - Returns: The JSON object of the attachment.
    static func encodedAttachment(of transcript: Transcript) throws -> [String: Any] {
      let data = try JSONEncoder().encode(transcript)
      let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
      let entries = try #require(
        (object["transcript"] as? [String: Any])?["entries"] as? [[String: Any]]
      )
      let contents = try #require(entries.first?["contents"] as? [[String: Any]])
      return try #require(contents.first?["attachment"] as? [String: Any])
    }
  }
#endif  // compiler(>=6.4)
