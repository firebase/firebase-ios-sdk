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
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  #if canImport(CoreGraphics)
    public import CoreGraphics
  #endif
  #if canImport(CoreImage)
    public import CoreImage
  #endif
  #if canImport(CoreVideo)
    public import CoreVideo
  #endif
  #if canImport(ImageIO)
    public import ImageIO
  #endif
  #if canImport(UniformTypeIdentifiers)
    #if compiler(>=6.4.2)
      public import UniformTypeIdentifiers
    #else
      import UniformTypeIdentifiers
    #endif
  #endif

  extension Transcript {
    /// An attachment in a transcript, such as an image or arbitrary binary data.
    ///
    /// - SeeAlso: [`Transcript.Attachment`](https://developer.apple.com/documentation/foundationmodels/transcript/attachment)
    @nonexhaustive
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public enum Attachment: Sendable, Equatable {
      /// An image attachment.
      case image(Transcript.ImageAttachment)

      #if compiler(>=6.4.2)
        /// A data attachment with a uniform type identifier and optional metadata.
        @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
        @available(tvOS, unavailable)
        case data(Transcript.DataAttachment)
      #endif  // compiler(>=6.4.2)

      /// Returns a Boolean value indicating whether two attachments are equal.
      ///
      /// - Parameters:
      ///   - a: The first attachment to compare.
      ///   - b: The second attachment to compare.
      /// - Returns: `true` if the attachments are equal; otherwise, `false`.
      public static func == (a: Transcript.Attachment, b: Transcript.Attachment) -> Bool {
        switch (a, b) {
        case (.image(let a), .image(let b)):
          a == b
        #if compiler(>=6.4.2)
          case (.data(let a), .data(let b)):
            a == b
          default:
            false
        #endif  // compiler(>=6.4.2)
        }
      }
    }
  }

  extension Transcript {
    #if compiler(>=6.4.2)
      /// A data attachment that stores raw bytes, a uniform type identifier, and metadata.
      ///
      /// - SeeAlso: [`Transcript.DataAttachment`](https://developer.apple.com/documentation/foundationmodels/transcript/dataattachment)
      @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
      @available(tvOS, unavailable)
      public struct DataAttachment: Sendable, Equatable {
        /// The uniform type identifier of the attachment data.
        public var contentType: UTType

        /// The raw bytes of the attachment.
        public var content: Data

        /// The metadata associated with the attachment.
        public var metadata: GeneratedContent

        /// Creates a data attachment with the given type, content, and metadata.
        ///
        /// - Parameters:
        ///   - contentType: The uniform type identifier of the data.
        ///   - content: The raw data bytes.
        ///   - metadata: Additional metadata for the attachment.
        public init(
          contentType: UTType,
          content: Data,
          metadata: GeneratedContent = GeneratedContent(properties: [:])
        ) {
          self.contentType = contentType
          self.content = content
          self.metadata = metadata
        }

        /// Returns a Boolean value indicating whether two data attachments are equal.
        ///
        /// - Parameters:
        ///   - lhs: The first data attachment to compare.
        ///   - rhs: The second data attachment to compare.
        /// - Returns: `true` if the attachments are equal; otherwise, `false`.
        public static func == (lhs: Transcript.DataAttachment, rhs: Transcript.DataAttachment)
          -> Bool
        {
          lhs.contentType == rhs.contentType
            && lhs.content == rhs.content
            && metadataEquals(lhs.metadata, rhs.metadata)
        }
      }
    #endif  // compiler(>=6.4.2)
  }

  #if compiler(>=6.4.2)
    /// A type that can represent and convert to a transcript data attachment.
    ///
    /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
    /// > only. For the production API, see
    /// > [`DataAttachmentRepresentable`](https://developer.apple.com/documentation/foundationmodels/dataattachmentrepresentable).
    @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
    @available(tvOS, unavailable)
    public protocol DataAttachmentRepresentable: Sendable {
      /// Creates an instance from a transcript data attachment.
      ///
      /// - Parameter attachment: The transcript data attachment to convert from.
      /// - Throws: An error if conversion fails.
      init(_ attachment: Transcript.DataAttachment) throws

      /// The transcript data attachment representation of this instance.
      var transcriptRepresentation: Transcript.DataAttachment { get }
    }
  #endif  // compiler(>=6.4.2)

  extension Transcript {
    /// An image attachment in a transcript.
    ///
    /// - SeeAlso: [`Transcript.ImageAttachment`](https://developer.apple.com/documentation/foundationmodels/transcript/imageattachment)
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct ImageAttachment: Sendable, Equatable {
      /// The shared storage of the image, whose identity defines equality.
      let storage: ImageAttachmentStorage

      /// Creates an image attachment from an image source and display orientation.
      ///
      /// - Parameters:
      ///   - source: Where the image comes from.
      ///   - orientation: The display orientation of the image, or `nil` for `.up`.
      init(source: ImageAttachmentStorage.Source, orientation: CGImagePropertyOrientation?) {
        self.storage = ImageAttachmentStorage(source: source, orientation: orientation ?? .up)
      }

      /// Returns a Boolean value indicating whether two image attachments are equal.
      ///
      /// - Parameters:
      ///   - a: The first image attachment to compare.
      ///   - b: The second image attachment to compare.
      /// - Returns: `true` if the attachments are equal; otherwise, `false`.
      public static func == (a: Transcript.ImageAttachment, b: Transcript.ImageAttachment) -> Bool {
        a.storage === b.storage
      }
    }
  }

  /// The immutable storage behind a ``Transcript/ImageAttachment``.
  ///
  /// The fake keeps the original source and converts on demand. The class's identity gives
  /// attachments copy-based equality: copies of an attachment are equal, and separately created
  /// attachments aren't.
  final class ImageAttachmentStorage {
    /// The origin of an attached image.
    enum Source {
      /// An image referenced by a URL (`file:`, `data:`, or remote).
      case url(URL)

      #if canImport(CoreGraphics)
        /// A Core Graphics image.
        case cgImage(CGImage)
      #endif

      #if canImport(CoreImage)
        /// A Core Image image.
        case ciImage(CIImage)
      #endif

      #if canImport(CoreVideo)
        /// A Core Video pixel buffer.
        case pixelBuffer(CVPixelBuffer)
      #endif
    }

    /// The origin of the image.
    let source: Source

    /// The display orientation of the image.
    let orientation: CGImagePropertyOrientation

    /// Creates storage for an image source and orientation.
    ///
    /// - Parameters:
    ///   - source: The origin of the image.
    ///   - orientation: The display orientation of the image.
    init(source: Source, orientation: CGImagePropertyOrientation) {
      self.source = source
      self.orientation = orientation
    }
  }

  extension Transcript.ImageAttachment {
    /// The URL of the image, or `nil` if the attachment was not created from a URL.
    public var url: URL? {
      guard case .url(let url) = storage.source else {
        return nil
      }
      return url
    }
  }

  extension Transcript.ImageAttachment {
    #if canImport(CoreGraphics)
      /// A Core Graphics representation of the image attachment.
      ///
      /// If the image can't be loaded (for example, a remote URL, which the fake never fetches, or
      /// bytes that aren't an image), this is a transparent 1×1 placeholder image.
      public var cgImage: CGImage {
        storage.makeCGImage() ?? ImageAttachmentStorage.placeholderImage
      }
    #endif

    #if canImport(CoreImage)
      /// A Core Image representation of the image attachment.
      public var ciImage: CIImage {
        switch storage.source {
        case .ciImage(let ciImage):
          return ciImage
        #if canImport(CoreVideo)
          case .pixelBuffer(let pixelBuffer):
            return CIImage(cvPixelBuffer: pixelBuffer)
        #endif
        default:
          return CIImage(cgImage: cgImage)
        }
      }
    #endif

    #if canImport(CoreVideo)
      /// Creates a read-only pixel buffer containing the image.
      ///
      /// - Parameters:
      ///   - resolution: The target dimensions, or `nil` to use the image's dimensions.
      ///   - pixelFormat: The pixel format code, or `nil` for default 32-bit BGRA format.
      /// - Returns: A read-only pixel buffer that contains the rendered image.
      /// - Throws: An error if the pixel buffer cannot be created.
      @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
      @available(tvOS, unavailable)
      public func pixelBuffer(
        resolution: CGSize? = nil,
        pixelFormat: OSType? = nil
      ) throws -> CVReadOnlyPixelBuffer {
        #if canImport(CoreImage)
          let buffer = try storage.makePixelBuffer(
            image: ciImage,
            resolution: resolution,
            pixelFormat: pixelFormat ?? kCVPixelFormatType_32BGRA
          )
          return CVReadOnlyPixelBuffer(unsafeBuffer: buffer)
        #else
          throw ImageAttachmentError.conversionFailed
        #endif
      }
    #endif

    /// The display orientation of the image.
    public var orientation: CGImagePropertyOrientation {
      storage.orientation
    }

    #if canImport(CoreGraphics)
      /// Creates an image attachment from a Core Graphics image and display orientation.
      ///
      /// - Parameters:
      ///   - cgImage: The Core Graphics image to attach.
      ///   - orientation: The display orientation of the image, or `nil` for `.up`.
      public init(_ cgImage: CGImage, orientation: CGImagePropertyOrientation? = nil) {
        self.init(source: .cgImage(cgImage), orientation: orientation)
      }
    #endif

    #if canImport(CoreImage)
      /// Creates an image attachment from a Core Image image and display orientation.
      ///
      /// - Parameters:
      ///   - ciImage: The Core Image image to attach.
      ///   - orientation: The display orientation of the image, or `nil` to read from the image.
      public init(_ ciImage: CIImage, orientation: CGImagePropertyOrientation? = nil) {
        let resolvedOrientation =
          orientation ?? ImageAttachmentStorage.defaultOrientation(for: ciImage)
        self.init(source: .ciImage(ciImage), orientation: resolvedOrientation)
      }
    #endif

    #if canImport(CoreVideo)
      /// Creates an image attachment from a Core Video pixel buffer and display orientation.
      ///
      /// - Parameters:
      ///   - pixelBuffer: The Core Video pixel buffer to attach.
      ///   - orientation: The display orientation of the image, or `nil` for `.up`.
      public init(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation? = nil) {
        self.init(source: .pixelBuffer(pixelBuffer), orientation: orientation)
      }
    #endif

    /// Creates an image attachment from an image URL and display orientation.
    ///
    /// - Parameters:
    ///   - imageURL: The URL referencing the image.
    ///   - orientation: The display orientation of the image, or `nil` to read from image metadata.
    public init(imageURL: URL, orientation: CGImagePropertyOrientation? = nil) {
      let resolvedOrientation =
        orientation ?? ImageAttachmentStorage.defaultOrientation(for: imageURL)
      self.init(source: .url(imageURL), orientation: resolvedOrientation)
    }
  }

  /// Errors from converting image attachments between representations.
  enum ImageAttachmentError: Error, CustomStringConvertible {
    /// The image couldn't be converted to the requested representation.
    case conversionFailed

    /// A textual representation of this error.
    var description: String {
      switch self {
      case .conversionFailed:
        "The image attachment couldn't be converted."
      }
    }
  }

  #if canImport(CoreGraphics) || canImport(CoreImage) || canImport(CoreVideo)
    // `@unchecked` because the Apple-only sources (`CGImage`, `CIImage`, `CVPixelBuffer`) aren't
    // all `Sendable`. The storage is immutable (`let` properties only) and never mutates the
    // images it holds, and Core Graphics and Core Image images are immutable and thread-safe.
    // Pixel buffers are only read (rendered or wrapped), never written.
    extension ImageAttachmentStorage: @unchecked Sendable {}
  #else
    // On platforms without Apple image types the storage only holds a `URL`.
    extension ImageAttachmentStorage: Sendable {}
  #endif

  // MARK: - Image data

  extension ImageAttachmentStorage {
    /// Returns the embedded EXIF orientation at image index `0` for local `file:` or `data:` URLs,
    /// or `.up` if untagged, remote, or unreadable.
    static func defaultOrientation(for url: URL) -> CGImagePropertyOrientation {
      #if canImport(ImageIO)
        let imageSource: CGImageSource?
        if url.isFileURL {
          imageSource = CGImageSourceCreateWithURL(url as CFURL, nil)
        } else if url.scheme?.lowercased() == "data",
          let data = dataURLPayload(url.absoluteString)
        {
          imageSource = CGImageSourceCreateWithData(data as CFData, nil)
        } else {
          imageSource = nil
        }
        guard let imageSource,
          CGImageSourceGetCount(imageSource) > 0,
          let props = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        else {
          return .up
        }
        if let number = props[kCGImagePropertyOrientation] as? NSNumber,
          let parsed = CGImagePropertyOrientation(rawValue: number.uint32Value)
        {
          return parsed
        }
        if let raw = props[kCGImagePropertyOrientation] as? UInt32,
          let parsed = CGImagePropertyOrientation(rawValue: raw)
        {
          return parsed
        }
      #endif
      return .up
    }

    #if canImport(CoreImage)
      /// Returns the embedded EXIF orientation property on `ciImage`, or `.up` if untagged.
      static func defaultOrientation(for ciImage: CIImage) -> CGImagePropertyOrientation {
        #if canImport(ImageIO)
          let key = kCGImagePropertyOrientation as String
          if let number = ciImage.properties[key] as? NSNumber,
            let parsed = CGImagePropertyOrientation(rawValue: number.uint32Value)
          {
            return parsed
          }
          if let raw = ciImage.properties[key] as? UInt32,
            let parsed = CGImagePropertyOrientation(rawValue: raw)
          {
            return parsed
          }
          if let rawInt = ciImage.properties[key] as? Int,
            let rawUInt = UInt32(exactly: rawInt),
            let parsed = CGImagePropertyOrientation(rawValue: rawUInt)
          {
            return parsed
          }
        #endif
        return .up
      }
    #endif

    /// Reads the bytes of a `file:` or `data:` URL without touching the network.
    ///
    /// - Parameter url: The URL to read.
    /// - Returns: The bytes, or `nil` if the URL is remote or unreadable.
    static func localData(at url: URL) -> Data? {
      if url.isFileURL {
        return try? Data(contentsOf: url)
      }
      if url.scheme?.lowercased() == "data" {
        return dataURLPayload(url.absoluteString)
      }
      return nil
    }

    /// Decodes the payload of a `data:` URL string.
    ///
    /// - Parameter string: A URL string such as `data:image/png;base64,iVBORw0KGgo=`.
    /// - Returns: The decoded bytes, or `nil` if the string isn't a valid `data:` URL.
    static func dataURLPayload(_ string: String) -> Data? {
      guard string.lowercased().hasPrefix("data:"),
        let comma = string.firstIndex(of: ",")
      else {
        return nil
      }
      let header = string[string.index(string.startIndex, offsetBy: 5)..<comma]
      let payload = String(string[string.index(after: comma)...])
      let isBase64 = header.split(separator: ";").dropFirst().contains { param in
        let trimmed = param.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace)
        return String(trimmed.reversed()).lowercased() == "base64"
      }
      if isBase64 {
        return Data(base64Encoded: payload, options: .ignoreUnknownCharacters)
      }
      return percentDecoded(payload)
    }

    /// Decodes percent escapes (`%20`) in the payload of a non-base64 `data:` URL.
    ///
    /// - Parameter payload: The text after the comma of a `data:` URL.
    /// - Returns: The decoded bytes, or `nil` if an escape is malformed.
    static func percentDecoded(_ payload: String) -> Data? {
      var bytes: [UInt8] = []
      var iterator = Array(payload.utf8).makeIterator()
      while let byte = iterator.next() {
        guard byte == UInt8(ascii: "%") else {
          bytes.append(byte)
          continue
        }
        guard let high = iterator.next(), let low = iterator.next(),
          let value = UInt8(String(decoding: [high, low], as: UTF8.self), radix: 16)
        else {
          return nil
        }
        bytes.append(value)
      }
      return Data(bytes)
    }

    /// Returns the MIME type of image bytes, sniffed from their signature.
    ///
    /// - Parameter data: Encoded image bytes.
    /// - Returns: An image MIME type, or `application/octet-stream` if the format is unknown.
    static func mimeType(sniffing data: Data) -> String {
      let bytes = [UInt8](data.prefix(64))
      func matches(_ signature: [UInt8], at offset: Int = 0) -> Bool {
        bytes.count >= offset + signature.count
          && Array(bytes[offset..<offset + signature.count]) == signature
      }
      if matches([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
        return "image/png"
      }
      if matches([0xFF, 0xD8, 0xFF]) {
        return "image/jpeg"
      }
      if matches(Array("GIF8".utf8)) {
        return "image/gif"
      }
      if matches(Array("RIFF".utf8)) && matches(Array("WEBP".utf8), at: 8) {
        return "image/webp"
      }
      if bytes.count >= 12 && matches(Array("ftyp".utf8), at: 4) {
        let boxSize =
          (Int(bytes[0]) << 24) | (Int(bytes[1]) << 16) | (Int(bytes[2]) << 8) | Int(bytes[3])
        let limit = boxSize >= 16 ? min(bytes.count, boxSize) : bytes.count
        var brands: [String] = [String(decoding: bytes[8..<12], as: UTF8.self)]
        var offset = 16
        while offset + 4 <= limit {
          brands.append(String(decoding: bytes[offset..<offset + 4], as: UTF8.self))
          offset += 4
        }
        if brands.contains(where: { $0 == "heic" || $0 == "heix" || $0 == "hevc" || $0 == "hevx" })
        {
          return "image/heic"
        }
        if brands.contains(where: { $0 == "mif1" || $0 == "msf1" }) {
          return "image/heif"
        }
      }
      if matches([0x49, 0x49, 0x2A, 0x00]) || matches([0x4D, 0x4D, 0x00, 0x2A]) {
        return "image/tiff"
      }
      if matches([0x42, 0x4D]) {
        return "image/bmp"
      }
      return "application/octet-stream"
    }

    /// Returns a `data:` URL string that embeds the given bytes.
    ///
    /// - Parameter data: Encoded image bytes.
    /// - Returns: A base64 `data:` URL whose MIME type is sniffed from `data`.
    static func dataURLString(for data: Data) -> String {
      "data:\(mimeType(sniffing: data));base64,\(data.base64EncodedString())"
    }
  }

  // MARK: - Apple image conversions

  #if canImport(CoreGraphics)
    extension ImageAttachmentStorage {
      /// Converts the source to a Core Graphics image.
      ///
      /// - Returns: The image, or `nil` if it can't be loaded or rendered.
      func makeCGImage() -> CGImage? {
        switch source {
        case .url(let url):
          #if canImport(ImageIO)
            let imageSource: CGImageSource?
            if url.isFileURL {
              imageSource = CGImageSourceCreateWithURL(url as CFURL, nil)
            } else if let data = Self.localData(at: url) {
              imageSource = CGImageSourceCreateWithData(data as CFData, nil)
            } else {
              imageSource = nil
            }
            guard let imageSource, CGImageSourceGetCount(imageSource) > 0 else {
              return nil
            }
            return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
          #else
            return nil
          #endif
        case .cgImage(let image):
          return image
        #if canImport(CoreImage)
          case .ciImage(let image):
            return Self.render(image)
        #endif
        #if canImport(CoreVideo)
          case .pixelBuffer(let pixelBuffer):
            #if canImport(CoreImage)
              return Self.render(CIImage(cvPixelBuffer: pixelBuffer))
            #else
              return nil
            #endif
        #endif
        }
      }

      /// A transparent 1×1 image to use when an attachment can't be loaded, created once.
      static let placeholderImage: CGImage = makePlaceholderImage()

      /// Creates a transparent 1×1 image.
      ///
      /// Tries a bitmap context first and a data provider second; both only fail when Core
      /// Graphics can't allocate 4 bytes, so the final trap is unreachable in practice and runs
      /// at most once because the result is cached in ``placeholderImage``.
      ///
      /// - Returns: A transparent 1×1 RGBA image.
      private static func makePlaceholderImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        if let context = unsafe CGContext(
          data: nil,
          width: 1,
          height: 1,
          bitsPerComponent: 8,
          bytesPerRow: 4,
          space: colorSpace,
          bitmapInfo: bitmapInfo.rawValue
        ), let image = context.makeImage() {
          return image
        }
        if let provider = CGDataProvider(data: Data(count: 4) as CFData),
          let image = unsafe CGImage(
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
          )
        {
          return image
        }
        preconditionFailure("Core Graphics couldn't allocate a 1×1 placeholder image.")
      }

      #if canImport(ImageIO)
        /// Encodes the source as JPEG bytes.
        ///
        /// - Returns: JPEG data, or `nil` if the image can't be rendered or encoded.
        func jpegData() -> Data? {
          guard let image = makeCGImage() else {
            return nil
          }
          let data = NSMutableData()
          guard
            let destination = CGImageDestinationCreateWithData(
              data as CFMutableData,
              "public.jpeg" as CFString,
              1,
              nil
            )
          else {
            return nil
          }
          let properties: CFDictionary? =
            orientation == .up
            ? nil
            : ([kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary)
          CGImageDestinationAddImage(destination, image, properties)
          guard CGImageDestinationFinalize(destination) else {
            return nil
          }
          return data as Data
        }
      #endif
    }
  #endif

  #if canImport(CoreImage)
    extension ImageAttachmentStorage {
      /// Shared Core Image rendering context reused across attachment conversions.
      fileprivate static let ciContext = CIContext()

      /// Renders a Core Image image into a Core Graphics image.
      ///
      /// - Parameter image: The image to render.
      /// - Returns: The rendered image, or `nil` if rendering fails or the extent is infinite.
      static func render(_ image: CIImage) -> CGImage? {
        guard !image.extent.isInfinite else {
          return nil
        }
        return ciContext.createCGImage(image, from: image.extent)
      }
    }
  #endif

  #if canImport(CoreVideo) && canImport(CoreImage)
    extension ImageAttachmentStorage {
      /// Renders an image into a new pixel buffer.
      ///
      /// - Parameters:
      ///   - image: The image to render.
      ///   - resolution: The size of the buffer, or `nil` for the image's own size.
      ///   - pixelFormat: The pixel format of the buffer.
      /// - Returns: A pixel buffer that contains the rendered image.
      /// - Throws: ``ImageAttachmentError/conversionFailed`` if the buffer can't be created.
      func makePixelBuffer(
        image: CIImage,
        resolution: CGSize?,
        pixelFormat: OSType
      ) throws -> CVPixelBuffer {
        guard !image.extent.isInfinite, !image.extent.isEmpty else {
          throw ImageAttachmentError.conversionFailed
        }
        let size = resolution ?? image.extent.size
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width > 0, height > 0 else {
          throw ImageAttachmentError.conversionFailed
        }
        let attributes: [CFString: Any] = [
          kCVPixelBufferCGImageCompatibilityKey: true,
          kCVPixelBufferCGBitmapContextCompatibilityKey: true,
          kCVPixelBufferIOSurfacePropertiesKey: [:] as [CFString: Any],
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = unsafe CVPixelBufferCreate(
          kCFAllocatorDefault,
          width,
          height,
          pixelFormat,
          attributes as CFDictionary,
          &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
          throw ImageAttachmentError.conversionFailed
        }
        let scaled =
          image
          .transformed(
            by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY)
          )
          .transformed(
            by: CGAffineTransform(
              scaleX: CGFloat(width) / image.extent.width,
              y: CGFloat(height) / image.extent.height
            )
          )
        Self.ciContext.render(scaled, to: pixelBuffer)
        return pixelBuffer
      }
    }
  #endif
#endif  // compiler(>=6.4)
