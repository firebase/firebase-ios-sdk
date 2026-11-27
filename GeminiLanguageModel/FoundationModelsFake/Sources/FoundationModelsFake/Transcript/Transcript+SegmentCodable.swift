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
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  #if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
  #endif

  /// The transcript JSON form of `Transcript.Segment`.
  ///
  /// Segments are `{"type": "text", "id", "text"}`,
  /// `{"type": "structure", "id", "structure": {"source", "content"}}` with the content embedded
  /// as JSON, or `{"type": "attachment", "id", "attachment": {"type": "image", "data", "label"?}}`.
  struct TranscriptCodableSegment: Codable {
    /// The segment this value wraps.
    var segment: Transcript.Segment

    /// The JSON keys of a segment.
    enum CodingKeys: String, CodingKey {
      case type
      case id
      case text
      case structure
      case attachment
    }

    /// The JSON keys of the `structure` object.
    enum StructureCodingKeys: String, CodingKey {
      case source
      case content
    }

    /// Wraps a segment for coding.
    ///
    /// - Parameter segment: The segment to encode.
    init(_ segment: Transcript.Segment) {
      self.segment = segment
    }

    /// Creates a segment by decoding from the given decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the type is unknown or a value is missing or invalid.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      let id = try container.decode(String.self, forKey: .id)
      switch type {
      case "text":
        let text = try container.decode(String.self, forKey: .text)
        segment = .text(Transcript.TextSegment(id: id, content: text))
      case "structure":
        let structure = try container.nestedContainer(
          keyedBy: StructureCodingKeys.self,
          forKey: .structure
        )
        let source = try structure.decode(String.self, forKey: .source)
        segment = .structure(
          Transcript.StructuredSegment(
            id: id,
            schemaName: source,
            content: try structure.decodeTranscriptContent(forKey: .content)
          )
        )
      case "attachment":
        let attachment = try container.decode(TranscriptCodableAttachment.self, forKey: .attachment)
        segment = .attachment(
          Transcript.AttachmentSegment(id: id, content: attachment.content, label: attachment.label)
        )
      default:
        throw DecodingError.dataCorruptedError(
          forKey: .type,
          in: container,
          debugDescription: "Unsupported segment type: \(type)"
        )
      }
    }

    /// Encodes the segment into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if an image can't be loaded,
    ///   or an encoding error.
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch segment {
      case .text(let text):
        try container.encode("text", forKey: .type)
        try container.encode(text.id, forKey: .id)
        try container.encode(text.content, forKey: .text)
      case .structure(let structure):
        try container.encode("structure", forKey: .type)
        try container.encode(structure.id, forKey: .id)
        var nested = container.nestedContainer(
          keyedBy: StructureCodingKeys.self, forKey: .structure)
        try nested.encode(structure.schemaName, forKey: .source)
        try nested.encodeTranscriptContent(structure.content, forKey: .content)
      case .attachment(let attachment):
        try container.encode("attachment", forKey: .type)
        try container.encode(attachment.id, forKey: .id)
        try container.encode(
          TranscriptCodableAttachment(content: attachment.content, label: attachment.label),
          forKey: .attachment
        )
      }
    }
  }

  /// The `attachment` object of an attachment segment in transcript JSON.
  ///
  /// The fake keeps the attachment's URL rather than re-encoding every image: `data:` URLs and
  /// remote URLs are written verbatim (remote URLs are never fetched), `file:` URLs are read and
  /// embedded as a `data:` URL whose MIME type is sniffed from the bytes, and on Apple platforms
  /// in-memory images are encoded as JPEG `data:` URLs. Decoding rejects `file:` URLs and
  /// yields an attachment backed by the decoded URL.
  ///
  /// File images are read whole with no size limit, so encode transcripts only with images you
  /// trust.
  struct TranscriptCodableAttachment: Codable {
    /// The attached content.
    var content: Transcript.Attachment

    /// The attachment's label, if it has one.
    var label: String?

    /// The JSON keys of an attachment.
    enum CodingKeys: String, CodingKey {
      case type
      case data
      case label
      case contentType
      case content
      case metadata
    }

    /// Creates an attachment value for coding.
    ///
    /// - Parameters:
    ///   - content: The attached content.
    ///   - label: The attachment's label, or `nil`.
    init(content: Transcript.Attachment, label: String?) {
      self.content = content
      self.label = label
    }

    /// Creates an attachment by decoding from the given decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the type is unknown, or the image data isn't a URL or is a
    ///   `file:` URL.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      switch type {
      case "image":
        let data = try container.decode(String.self, forKey: .data)
        guard let url = URL(string: data) else {
          throw DecodingError.dataCorruptedError(
            forKey: .data,
            in: container,
            debugDescription: "The image data isn't a valid URL."
          )
        }
        // The encoder writes every URL verbatim except `file:` URLs, which it reads and embeds, so
        // accepting them would let decoded JSON make a later encode read an arbitrary local file.
        guard !url.isFileURL else {
          throw DecodingError.dataCorruptedError(
            forKey: .data,
            in: container,
            debugDescription: "The image data can't be a file URL."
          )
        }
        self.content = .image(Transcript.ImageAttachment(imageURL: url))
        self.label = try container.decodeIfPresent(String.self, forKey: .label)
      #if compiler(>=6.4.2)
        case "data":
          let typeID = try container.decode(String.self, forKey: .contentType)
          let contentType =
            (try? container.decode(UTType.self, forKey: .contentType))
            ?? UTType(typeID)
            ?? (typeID.isEmpty ? .data : UTType(importedAs: typeID))
          let payload = try container.decode(Data.self, forKey: .content)
          let metadata =
            try container.decodeIfPresent(CodableGeneratedContent.self, forKey: .metadata)?.content
            ?? GeneratedContent(properties: [:])
          self.content = .data(
            Transcript.DataAttachment(
              contentType: contentType,
              content: payload,
              metadata: metadata
            )
          )
          self.label = try container.decodeIfPresent(String.self, forKey: .label)
      #endif  // compiler(>=6.4.2)
      default:
        throw DecodingError.dataCorruptedError(
          forKey: .type,
          in: container,
          debugDescription: "Unsupported attachment type: \(type)"
        )
      }
    }

    /// Encodes the attachment into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if an image can't be loaded,
    ///   or an encoding error.
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch content {
      case .image(let image):
        try container.encode("image", forKey: .type)
        try container.encode(try image.storage.transcriptDataURLString(), forKey: .data)
      #if compiler(>=6.4.2)
        case .data(let dataAttachment):
          try container.encode("data", forKey: .type)
          try container.encode(dataAttachment.contentType.identifier, forKey: .contentType)
          try container.encode(dataAttachment.content, forKey: .content)
          try container.encodeTranscriptContent(dataAttachment.metadata, forKey: .metadata)
      #endif  // compiler(>=6.4.2)
      }
      try container.encodeIfPresent(label, forKey: .label)
    }
  }

  extension ImageAttachmentStorage {
    /// Returns the URL string that represents this image in transcript JSON.
    ///
    /// - Returns: A `data:` URL for local and in-memory images, or the remote URL verbatim.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if the image can't be loaded.
    func transcriptDataURLString() throws -> String {
      switch source {
      case .url(let url):
        if url.isFileURL {
          guard let data = try? Data(contentsOf: url) else {
            throw Self.loadError("The image at \(url.absoluteString) couldn't be loaded.")
          }
          return Self.dataURLString(for: data)
        }
        return url.absoluteString
      #if canImport(CoreGraphics)
        default:
          #if canImport(ImageIO)
            guard let data = jpegData() else {
              throw Self.loadError("Could not encode image.")
            }
            return Self.dataURLString(for: data)
          #else
            throw Self.loadError("Could not encode image.")
          #endif
      #endif
      }
    }

    /// Returns the error thrown when an image in a transcript can't be loaded.
    ///
    /// - Parameter debugDescription: A description of the failure.
    /// - Returns: A `LanguageModelError.unsupportedTranscriptContent` error.
    static func loadError(_ debugDescription: String) -> LanguageModelError {
      .unsupportedTranscriptContent(
        LanguageModelError.UnsupportedTranscriptContent(
          unsupportedContent: [],
          debugDescription: debugDescription
        )
      )
    }
  }
#endif  // compiler(>=6.4)
