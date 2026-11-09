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
  #if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
  #else
    #if canImport(FoundationEssentials)
      import FoundationEssentials
    #else
      import Foundation
    #endif

    /// A uniform type identifier representing a file format or data type on platforms without
    /// UniformTypeIdentifiers.
    public struct UTType: Sendable, Hashable, Codable, CustomStringConvertible {
      /// The uniform type identifier string.
      public let identifier: String

      /// The set of ancestor type identifiers that this type conforms to.
      private let parentIdentifiers: Set<String>

      /// Creates a uniform type from an identifier string, and a set of ancestor identifiers.
      private init(identifier: String, parentIdentifiers: Set<String>) {
        self.identifier = identifier
        self.parentIdentifiers = parentIdentifiers
      }

      /// Creates a uniform type from an identifier string.
      ///
      /// - Parameter identifier: The uniform type identifier string.
      public init?(_ identifier: String) {
        guard !identifier.allSatisfy(\.isWhitespace) else {
          return nil
        }
        let normalized = identifier.lowercased()
        self.identifier = identifier
        self.parentIdentifiers = Self.knownParentIdentifiers(for: normalized)
      }

      /// Creates an imported uniform type with an identifier and an optional supertype.
      ///
      /// - Parameters:
      ///   - identifier: The uniform type identifier string.
      ///   - parentType: The supertype that the imported type conforms to, or `nil`.
      public init(importedAs identifier: String, conformingTo parentType: UTType? = nil) {
        self.identifier = identifier
        if let parentType {
          var parents = parentType.parentIdentifiers
          parents.insert(parentType.identifier.lowercased())
          self.parentIdentifiers = parents
        } else {
          self.parentIdentifiers = Self.knownParentIdentifiers(for: identifier.lowercased())
        }
      }

      /// Creates an exported uniform type with an identifier and an optional supertype.
      ///
      /// - Parameters:
      ///   - identifier: The uniform type identifier string.
      ///   - parentType: The supertype that the exported type conforms to, or `nil`.
      public init(exportedAs identifier: String, conformingTo parentType: UTType? = nil) {
        self.init(importedAs: identifier, conformingTo: parentType)
      }

      /// Creates a uniform type corresponding to a MIME type.
      ///
      /// - Parameter mimeType: The MIME type string.
      public init?(mimeType: String) {
        let trimmed = String(
          mimeType.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed()
        )
        guard !trimmed.isEmpty else {
          return nil
        }
        let baseMIME =
          trimmed.split(separator: ";", maxSplits: 1).first.map(String.init)?.lowercased()
          ?? trimmed.lowercased()
        if let known = Self.mimeTypeToUTType[baseMIME] {
          self = known
        } else {
          let sanitized = baseMIME.replacing("/", with: ".")
          self.init(
            identifier: "dyn.mime.\(sanitized)",
            parentIdentifiers: ["public.data", "public.item"]
          )
        }
      }

      /// A textual representation of the uniform type identifier.
      public var description: String {
        identifier
      }

      /// Creates a uniform type from a filename extension conforming to a supertype.
      ///
      /// - Parameters:
      ///   - filenameExtension: The file extension string.
      ///   - supertype: The supertype that the resulting type must conform to.
      public init?(filenameExtension: String, conformingTo supertype: UTType = .data) {
        let normalized = filenameExtension.lowercased()
        guard !normalized.isEmpty, !normalized.contains(".") else {
          return nil
        }
        if let mimeType = Self.filenameExtensionToMIMEType[normalized],
          let known = Self.mimeTypeToUTType[mimeType],
          known.conforms(to: supertype)
        {
          self = known
          return
        }
        var parents = supertype.parentIdentifiers
        parents.insert(supertype.identifier.lowercased())
        self.init(identifier: "dyn.ext.\(normalized)", parentIdentifiers: parents)
      }

      /// The preferred MIME type corresponding to this uniform type, if known.
      public var preferredMIMEType: String? {
        Self.identifierToMIMEType[identifier.lowercased()]
      }

      /// Returns whether this type conforms to the specified type.
      ///
      /// - Parameter type: The candidate supertype.
      /// - Returns: `true` if this type conforms to `type`; otherwise, `false`.
      public func conforms(to type: UTType) -> Bool {
        let target = type.identifier.lowercased()
        return identifier.lowercased() == target || parentIdentifiers.contains(target)
      }

      /// Returns whether two uniform types are equal.
      ///
      /// - Parameters:
      ///   - lhs: The first uniform type.
      ///   - rhs: The second uniform type.
      /// - Returns: `true` if both types have equal identifiers; otherwise, `false`.
      public static func == (lhs: UTType, rhs: UTType) -> Bool {
        lhs.identifier.lowercased() == rhs.identifier.lowercased()
      }

      /// Hashes the essential components of this uniform type into the given hasher.
      ///
      /// - Parameter hasher: The hasher to use when combining components.
      public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier.lowercased())
      }

      // MARK: - Codable

      /// The JSON keys of a uniform type.
      private enum CodingKeys: String, CodingKey {
        /// The type's identifier.
        case identifier
      }

      /// Creates a uniform type by decoding from the given decoder.
      ///
      /// - Parameter decoder: The decoder to read data from.
      /// - Throws: An error if decoding fails or the identifier is invalid.
      public init(from decoder: any Decoder) throws {
        if let singleValueContainer = try? decoder.singleValueContainer(),
          let rawIdentifier = try? singleValueContainer.decode(String.self)
        {
          guard let decoded = UTType(rawIdentifier) else {
            throw DecodingError.dataCorruptedError(
              in: singleValueContainer,
              debugDescription: "Invalid UTType identifier: \(rawIdentifier)"
            )
          }
          self = decoded
          return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawIdentifier = try container.decode(String.self, forKey: .identifier)
        guard let decoded = UTType(rawIdentifier) else {
          throw DecodingError.dataCorruptedError(
            forKey: .identifier,
            in: container,
            debugDescription: "Invalid UTType identifier: \(rawIdentifier)"
          )
        }
        self = decoded
      }

      /// Encodes this uniform type into the given encoder.
      ///
      /// - Parameter encoder: The encoder to write data to.
      /// - Throws: An error if encoding fails.
      public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
      }

      // MARK: - Standard System Types

      /// A generic base type for any entity.
      public static let item = UTType(identifier: "public.item", parentIdentifiers: [])

      /// A base type for user-facing content.
      public static let content = UTType(identifier: "public.content", parentIdentifiers: [])

      /// A base type for composite content consisting of mixed media.
      public static let compositeContent = UTType(
        identifier: "public.composite-content",
        parentIdentifiers: ["public.content"]
      )

      /// A base type for raw binary data.
      public static let data = UTType(
        identifier: "public.data",
        parentIdentifiers: ["public.item"]
      )

      /// A base type for text data in any encoding.
      public static let text = UTType(
        identifier: "public.text",
        parentIdentifiers: ["public.data", "public.item", "public.content"]
      )

      /// A type representing plain text data.
      public static let plainText = UTType(
        identifier: "public.plain-text",
        parentIdentifiers: ["public.text", "public.data", "public.item", "public.content"]
      )

      /// A type representing UTF-8 plain text.
      public static let utf8PlainText = UTType(
        identifier: "public.utf8-plain-text",
        parentIdentifiers: [
          "public.plain-text", "public.text", "public.data", "public.item", "public.content",
        ]
      )

      /// A type representing comma-separated values (CSV) text.
      public static let commaSeparatedText = UTType(
        identifier: "public.comma-separated-values-text",
        parentIdentifiers: [
          "public.delimited-values-text", "public.text", "public.data", "public.item",
          "public.content",
        ]
      )

      /// A type representing HTML text.
      public static let html = UTType(
        identifier: "public.html",
        parentIdentifiers: ["public.text", "public.data", "public.item", "public.content"]
      )

      /// A type representing JSON data.
      public static let json = UTType(
        identifier: "public.json",
        parentIdentifiers: ["public.text", "public.data", "public.item", "public.content"]
      )

      /// A type representing XML data.
      public static let xml = UTType(
        identifier: "public.xml",
        parentIdentifiers: ["public.text", "public.data", "public.item", "public.content"]
      )

      /// A type representing property list data.
      public static let propertyList = UTType(
        identifier: "com.apple.property-list",
        parentIdentifiers: ["public.data", "public.item", "public.content"]
      )

      /// A base type for source code text.
      public static let sourceCode = UTType(
        identifier: "public.source-code",
        parentIdentifiers: [
          "public.plain-text", "public.text", "public.data", "public.item", "public.content",
        ]
      )

      /// A base type for image data.
      public static let image = UTType(
        identifier: "public.image",
        parentIdentifiers: ["public.data", "public.item", "public.content"]
      )

      /// A type representing JPEG image data.
      public static let jpeg = UTType(
        identifier: "public.jpeg",
        parentIdentifiers: ["public.image", "public.data", "public.item", "public.content"]
      )

      /// A type representing PNG image data.
      public static let png = UTType(
        identifier: "public.png",
        parentIdentifiers: ["public.image", "public.data", "public.item", "public.content"]
      )

      /// A type representing GIF image data.
      public static let gif = UTType(
        identifier: "com.compuserve.gif",
        parentIdentifiers: ["public.image", "public.data", "public.item", "public.content"]
      )

      /// A type representing WebP image data.
      public static let webP = UTType(
        identifier: "org.webmproject.webp",
        parentIdentifiers: ["public.image", "public.data", "public.item", "public.content"]
      )

      /// A type representing HEIC image data.
      public static let heic = UTType(
        identifier: "public.heic",
        parentIdentifiers: ["public.image", "public.data", "public.item", "public.content"]
      )

      /// A type representing HEIF image data.
      public static let heif = UTType(
        identifier: "public.heif",
        parentIdentifiers: ["public.image", "public.data", "public.item", "public.content"]
      )

      /// A type representing TIFF image data.
      public static let tiff = UTType(
        identifier: "public.tiff",
        parentIdentifiers: ["public.image", "public.data", "public.item", "public.content"]
      )

      /// A type representing Windows bitmap image data.
      public static let bmp = UTType(
        identifier: "com.microsoft.bmp",
        parentIdentifiers: ["public.image", "public.data", "public.item", "public.content"]
      )

      /// A type representing SVG image data.
      public static let svg = UTType(
        identifier: "public.svg-image",
        parentIdentifiers: [
          "public.image", "public.xml", "public.text", "public.data", "public.item",
          "public.content",
        ]
      )

      /// A type representing PDF document data.
      public static let pdf = UTType(
        identifier: "com.adobe.pdf",
        parentIdentifiers: [
          "public.data", "public.item", "public.composite-content", "public.content",
        ]
      )

      /// A base type for audio data.
      public static let audio = UTType(
        identifier: "public.audio",
        parentIdentifiers: [
          "public.audiovisual-content", "public.data", "public.item", "public.content",
        ]
      )

      /// A type representing MP3 audio data.
      public static let mp3 = UTType(
        identifier: "public.mp3",
        parentIdentifiers: [
          "public.audio", "public.audiovisual-content", "public.data", "public.item",
          "public.content",
        ]
      )

      /// A type representing waveform audio data.
      public static let wav = UTType(
        identifier: "com.microsoft.waveform-audio",
        parentIdentifiers: [
          "public.audio", "public.audiovisual-content", "public.data", "public.item",
          "public.content",
        ]
      )

      /// A type representing AIFF audio data.
      public static let aiff = UTType(
        identifier: "public.aiff-audio",
        parentIdentifiers: [
          "public.audio", "public.audiovisual-content", "public.data", "public.item",
          "public.content",
        ]
      )

      /// A type representing MPEG-4 audio data.
      public static let mpeg4Audio = UTType(
        identifier: "com.apple.m4a-audio",
        parentIdentifiers: [
          "public.mpeg-4-audio", "public.audio", "public.audiovisual-content", "public.data",
          "public.item", "public.content",
        ]
      )

      /// A base type for movie media containing video and audio.
      public static let movie = UTType(
        identifier: "public.movie",
        parentIdentifiers: [
          "public.audiovisual-content", "public.data", "public.item", "public.content",
        ]
      )

      /// A base type for video data without audio.
      public static let video = UTType(
        identifier: "public.video",
        parentIdentifiers: [
          "public.movie", "public.audiovisual-content", "public.data", "public.item",
          "public.content",
        ]
      )

      /// A type representing MPEG-4 movie data.
      public static let mpeg4Movie = UTType(
        identifier: "public.mpeg-4",
        parentIdentifiers: [
          "public.movie", "public.audiovisual-content", "public.data", "public.item",
          "public.content",
        ]
      )

      /// A type representing QuickTime movie data.
      public static let quickTimeMovie = UTType(
        identifier: "com.apple.quicktime-movie",
        parentIdentifiers: [
          "public.movie", "public.audiovisual-content", "public.data", "public.item",
          "public.content",
        ]
      )

      /// A type representing AVI movie data.
      public static let avi = UTType(
        identifier: "public.avi",
        parentIdentifiers: [
          "public.movie", "public.audiovisual-content", "public.data", "public.item",
          "public.content",
        ]
      )

      /// A type representing MPEG-1 or MPEG-2 movie data.
      public static let mpeg = UTType(
        identifier: "public.mpeg",
        parentIdentifiers: [
          "public.movie", "public.audiovisual-content", "public.data", "public.item",
          "public.content",
        ]
      )

      // MARK: - Lookup Tables

      /// The identifiers that every audio type conforms to.
      private static let audioAncestors: Set<String> = [
        "public.audio", "public.audiovisual-content", "public.data", "public.item",
        "public.content",
      ]

      /// The identifiers that every movie type conforms to.
      private static let movieAncestors: Set<String> = [
        "public.movie", "public.audiovisual-content", "public.data", "public.item",
        "public.content",
      ]

      /// The identifiers that every text type conforms to.
      private static let textAncestors: Set<String> = [
        "public.text", "public.data", "public.item", "public.content",
      ]

      /// The types the shim knows, keyed by lowercased identifier.
      private static let knownTypes: [String: UTType] = [
        "public.item": .item,
        "public.content": .content,
        "public.composite-content": .compositeContent,
        "public.data": .data,
        "public.text": .text,
        "public.plain-text": .plainText,
        "public.utf8-plain-text": .utf8PlainText,
        "public.comma-separated-values-text": .commaSeparatedText,
        "public.html": .html,
        "net.daringfireball.markdown": UTType(
          identifier: "net.daringfireball.markdown",
          parentIdentifiers: textAncestors
        ),
        "public.json": .json,
        "public.xml": .xml,
        "com.apple.property-list": .propertyList,
        "public.source-code": .sourceCode,
        "public.image": .image,
        "public.jpeg": .jpeg,
        "public.png": .png,
        "com.compuserve.gif": .gif,
        "org.webmproject.webp": .webP,
        "public.heic": .heic,
        "public.heif": .heif,
        "public.tiff": .tiff,
        "com.microsoft.bmp": .bmp,
        "public.svg-image": .svg,
        "com.adobe.pdf": .pdf,
        "public.audio": .audio,
        "public.mp3": .mp3,
        "com.microsoft.waveform-audio": .wav,
        "public.aiff-audio": .aiff,
        "com.apple.m4a-audio": .mpeg4Audio,
        "public.mpeg-4-audio": .mpeg4Audio,
        "public.aac-audio": UTType(
          identifier: "public.aac-audio", parentIdentifiers: audioAncestors),
        "org.xiph.ogg-audio": UTType(
          identifier: "org.xiph.ogg-audio",
          parentIdentifiers: audioAncestors
        ),
        "org.xiph.flac": UTType(identifier: "org.xiph.flac", parentIdentifiers: audioAncestors),
        "org.xiph.opus": UTType(identifier: "org.xiph.opus", parentIdentifiers: audioAncestors),
        "org.webmproject.webm-audio": UTType(
          identifier: "org.webmproject.webm-audio",
          parentIdentifiers: audioAncestors
        ),
        "public.3gpp-audio": UTType(
          identifier: "public.3gpp-audio",
          parentIdentifiers: audioAncestors
        ),
        "public.pcm-audio": UTType(
          identifier: "public.pcm-audio", parentIdentifiers: audioAncestors),
        "public.ulaw-audio": UTType(
          identifier: "public.ulaw-audio",
          parentIdentifiers: audioAncestors
        ),
        "public.alaw-audio": UTType(
          identifier: "public.alaw-audio",
          parentIdentifiers: audioAncestors
        ),
        "public.movie": .movie,
        "public.video": .video,
        "public.mpeg-4": .mpeg4Movie,
        "com.apple.quicktime-movie": .quickTimeMovie,
        "public.avi": .avi,
        "public.mpeg": .mpeg,
        "org.webmproject.webm": UTType(
          identifier: "org.webmproject.webm",
          parentIdentifiers: movieAncestors
        ),
        "public.3gpp": UTType(identifier: "public.3gpp", parentIdentifiers: movieAncestors),
        "com.adobe.flash.video": UTType(
          identifier: "com.adobe.flash.video",
          parentIdentifiers: movieAncestors
        ),
        "com.microsoft.windows-media-wmv": UTType(
          identifier: "com.microsoft.windows-media-wmv",
          parentIdentifiers: movieAncestors
        ),
      ]

      /// The preferred MIME type of each known type, keyed by identifier.
      private static let identifierToMIMEType: [String: String] = [
        "public.data": "application/octet-stream",
        "public.plain-text": "text/plain",
        "public.utf8-plain-text": "text/plain",
        "public.comma-separated-values-text": "text/csv",
        "public.html": "text/html",
        "net.daringfireball.markdown": "text/markdown",
        "public.json": "application/json",
        "public.xml": "application/xml",
        "com.apple.property-list": "application/x-plist",
        "public.jpeg": "image/jpeg",
        "public.png": "image/png",
        "com.compuserve.gif": "image/gif",
        "org.webmproject.webp": "image/webp",
        "public.heic": "image/heic",
        "public.heif": "image/heif",
        "public.tiff": "image/tiff",
        "com.microsoft.bmp": "image/bmp",
        "public.svg-image": "image/svg+xml",
        "com.adobe.pdf": "application/pdf",
        "public.mp3": "audio/mpeg",
        "com.microsoft.waveform-audio": "audio/wav",
        "public.aiff-audio": "audio/aiff",
        "com.apple.m4a-audio": "audio/m4a",
        "public.mpeg-4-audio": "audio/m4a",
        "public.aac-audio": "audio/aac",
        "org.xiph.ogg-audio": "audio/ogg",
        "org.xiph.flac": "audio/flac",
        "org.xiph.opus": "audio/opus",
        "org.webmproject.webm-audio": "audio/webm",
        "public.3gpp-audio": "audio/3gpp",
        "public.pcm-audio": "audio/pcm",
        "public.ulaw-audio": "audio/mulaw",
        "public.alaw-audio": "audio/alaw",
        "public.mpeg-4": "video/mp4",
        "com.apple.quicktime-movie": "video/quicktime",
        "public.avi": "video/avi",
        "public.mpeg": "video/mpeg",
        "org.webmproject.webm": "video/webm",
        "public.3gpp": "video/3gpp",
        "com.adobe.flash.video": "video/x-flv",
        "com.microsoft.windows-media-wmv": "video/wmv",
      ]

      /// The known type for each MIME type, keyed by lowercased MIME type.
      private static let mimeTypeToUTType: [String: UTType] = [
        "application/octet-stream": .data,
        "text/plain": .plainText,
        "text/csv": .commaSeparatedText,
        "text/html": .html,
        "text/markdown": UTType(
          identifier: "net.daringfireball.markdown",
          parentIdentifiers: textAncestors
        ),
        "application/json": .json,
        "application/xml": .xml,
        "text/xml": .xml,
        "application/x-plist": .propertyList,
        "image/jpeg": .jpeg,
        "image/jpg": .jpeg,
        "image/png": .png,
        "image/gif": .gif,
        "image/webp": .webP,
        "image/heic": .heic,
        "image/heif": .heif,
        "image/tiff": .tiff,
        "image/bmp": .bmp,
        "image/svg+xml": .svg,
        "application/pdf": .pdf,
        "audio/mpeg": .mp3,
        "audio/mp3": .mp3,
        "audio/wav": .wav,
        "audio/x-wav": .wav,
        "audio/wave": .wav,
        "audio/vnd.wave": .wav,
        "audio/aiff": .aiff,
        "audio/x-aiff": .aiff,
        "audio/m4a": .mpeg4Audio,
        "audio/x-m4a": .mpeg4Audio,
        "audio/mp4": .mpeg4Audio,
        "audio/aac": UTType(identifier: "public.aac-audio", parentIdentifiers: audioAncestors),
        "audio/ogg": UTType(identifier: "org.xiph.ogg-audio", parentIdentifiers: audioAncestors),
        "audio/flac": UTType(identifier: "org.xiph.flac", parentIdentifiers: audioAncestors),
        "audio/x-flac": UTType(identifier: "org.xiph.flac", parentIdentifiers: audioAncestors),
        "audio/opus": UTType(identifier: "org.xiph.opus", parentIdentifiers: audioAncestors),
        "audio/webm": UTType(
          identifier: "org.webmproject.webm-audio",
          parentIdentifiers: audioAncestors
        ),
        "audio/3gpp": UTType(identifier: "public.3gpp-audio", parentIdentifiers: audioAncestors),
        "audio/pcm": UTType(identifier: "public.pcm-audio", parentIdentifiers: audioAncestors),
        "audio/l16": UTType(identifier: "public.pcm-audio", parentIdentifiers: audioAncestors),
        "audio/mulaw": UTType(identifier: "public.ulaw-audio", parentIdentifiers: audioAncestors),
        "audio/alaw": UTType(identifier: "public.alaw-audio", parentIdentifiers: audioAncestors),
        "video/mp4": .mpeg4Movie,
        "video/quicktime": .quickTimeMovie,
        "video/mov": .quickTimeMovie,
        "video/avi": .avi,
        "video/x-msvideo": .avi,
        "video/mpeg": .mpeg,
        "video/mpg": .mpeg,
        "video/webm": UTType(identifier: "org.webmproject.webm", parentIdentifiers: movieAncestors),
        "video/3gpp": UTType(identifier: "public.3gpp", parentIdentifiers: movieAncestors),
        "video/x-flv": UTType(
          identifier: "com.adobe.flash.video",
          parentIdentifiers: movieAncestors
        ),
        "video/wmv": UTType(
          identifier: "com.microsoft.windows-media-wmv",
          parentIdentifiers: movieAncestors
        ),
      ]

      /// Maps lowercase filename extensions to the MIME types in ``mimeTypeToUTType``.
      private static let filenameExtensionToMIMEType: [String: String] = [
        "bin": "application/octet-stream",
        "txt": "text/plain",
        "text": "text/plain",
        "csv": "text/csv",
        "htm": "text/html",
        "html": "text/html",
        "md": "text/markdown",
        "markdown": "text/markdown",
        "json": "application/json",
        "xml": "application/xml",
        "plist": "application/x-plist",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "gif": "image/gif",
        "webp": "image/webp",
        "heic": "image/heic",
        "heif": "image/heif",
        "tif": "image/tiff",
        "tiff": "image/tiff",
        "bmp": "image/bmp",
        "svg": "image/svg+xml",
        "pdf": "application/pdf",
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "aif": "audio/aiff",
        "aiff": "audio/aiff",
        "m4a": "audio/m4a",
        "aac": "audio/aac",
        "ogg": "audio/ogg",
        "flac": "audio/flac",
        "opus": "audio/opus",
        "mp4": "video/mp4",
        "m4v": "video/mp4",
        "mov": "video/quicktime",
        "avi": "video/avi",
        "mpg": "video/mpeg",
        "mpeg": "video/mpeg",
        "webm": "video/webm",
        "3gp": "video/3gpp",
        "flv": "video/x-flv",
        "wmv": "video/wmv",
      ]

      /// Returns the identifiers that the type with `normalizedIdentifier` conforms to.
      ///
      /// - Parameter normalizedIdentifier: A lowercased type identifier.
      /// - Returns: The known type's parents, or `public.data` and `public.item` for an
      ///   unknown type.
      private static func knownParentIdentifiers(for normalizedIdentifier: String) -> Set<String> {
        if let known = knownTypes[normalizedIdentifier] {
          return known.parentIdentifiers
        }
        return ["public.data", "public.item"]
      }
    }
  #endif
#endif  // compiler(>=6.4)
