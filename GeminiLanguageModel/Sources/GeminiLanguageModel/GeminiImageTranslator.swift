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
  import ImageIO
  import UniformTypeIdentifiers

  /// Translates Foundation Models image attachments into Gemini API part data.
  ///
  /// Images are sent to Gemini as inline data:
  ///
  /// - File URLs whose bytes are already in a Gemini-supported format (PNG, JPEG, WebP, HEIC, or
  ///   HEIF) and that need no rotation are sent unchanged.
  /// - All other images (`CGImage` and `CVPixelBuffer` sources, other file formats, and images
  ///   with a non-`.up` orientation) are rotated to their display orientation and re-encoded as
  ///   JPEG, matching the format used by `Transcript`'s `Codable` conformance.
  ///
  /// Remote (non-file) URLs aren't supported.
  ///
  /// Only CoreGraphics, ImageIO, and UniformTypeIdentifiers are used so that the translation
  /// works on every platform that supports Foundation Models, including watchOS, which lacks
  /// CoreImage.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiImageTranslator {
    /// An error that occurs when an image attachment can't be translated.
    enum TranslationError: Error, Equatable, CustomStringConvertible {
      /// The attachment references a URL that isn't a file URL.
      case unsupportedURL(URL)

      /// The file referenced by the attachment couldn't be read.
      case unreadableFile(URL)

      /// The image data couldn't be decoded.
      case undecodableImage

      /// The image couldn't be rotated or encoded as JPEG.
      case encodingFailed

      /// A developer-facing description of the error.
      var description: String {
        switch self {
        case .unsupportedURL(let url):
          return "Image attachments with remote URLs aren't supported: \(url.absoluteString)"
        case .unreadableFile(let url):
          return "The image file couldn't be read: \(url.path)"
        case .undecodableImage:
          return "The image attachment data couldn't be decoded as an image."
        case .encodingFailed:
          return "The image attachment couldn't be encoded as JPEG."
        }
      }
    }

    /// The JPEG compression quality used when re-encoding images.
    ///
    /// This matches the quality used by `Transcript`'s `Codable` conformance.
    static let jpegCompressionQuality = 0.9

    /// The MIME type of re-encoded images.
    static let jpegMIMEType = "image/jpeg"

    /// The image types that Gemini accepts and that can be sent without re-encoding, mapped to
    /// their MIME types.
    static let passThroughMIMETypes: [UTType: String] = [
      .png: "image/png",
      .jpeg: "image/jpeg",
      .webP: "image/webp",
      .heic: "image/heic",
      .heif: "image/heif",
    ]

    // MARK: - Translation

    /// Translates an image attachment into Gemini part data.
    ///
    /// - Parameter attachment: The image attachment to translate.
    /// - Returns: Inline image data for a Gemini `Part`.
    /// - Throws: A ``TranslationError`` if the attachment references a remote URL, or if the image
    ///   can't be read, decoded, or encoded.
    static func partData(for attachment: Transcript.ImageAttachment) throws -> Part.PartData {
      // Reading `orientation` is safe for every attachment source. Reading `cgImage` isn't: it
      // traps for URL-backed attachments whose image couldn't be loaded (e.g., `gs://` URLs), so
      // URL-backed attachments are loaded from their file bytes instead.
      let orientation = attachment.orientation
      guard let url = attachment.url else {
        return try .inlineData(jpegBlob(for: attachment.cgImage, orientation: orientation))
      }
      guard url.isFileURL else {
        throw TranslationError.unsupportedURL(url)
      }
      return try .inlineData(blob(forFileAt: url, orientation: orientation))
    }

    /// Creates a blob from the image file at the given URL.
    ///
    /// - Parameters:
    ///   - url: The file URL of the image.
    ///   - orientation: The display orientation of the image.
    /// - Returns: A blob containing either the original file bytes or a re-encoded JPEG.
    /// - Throws: A ``TranslationError`` if the file can't be read, decoded, or encoded.
    static func blob(forFileAt url: URL, orientation: CGImagePropertyOrientation) throws -> Blob {
      let data: Data
      do {
        data = try Data(contentsOf: url)
      } catch {
        throw TranslationError.unreadableFile(url)
      }
      return try blob(forImageData: data, orientation: orientation)
    }

    /// Creates a blob from encoded image data.
    ///
    /// The data is sent unchanged when it's in a pass-through format, `orientation` is `.up`, and
    /// the data has no embedded non-default orientation. Otherwise, the image is decoded, rotated
    /// to its display orientation, and re-encoded as JPEG. An explicit `orientation` takes
    /// precedence over any orientation embedded in the data, matching
    /// `Transcript.ImageAttachment`.
    ///
    /// - Parameters:
    ///   - data: The encoded image data.
    ///   - orientation: The display orientation of the image.
    /// - Returns: A blob containing either `data` or a re-encoded JPEG.
    /// - Throws: A ``TranslationError`` if the data can't be decoded or encoded.
    static func blob(forImageData data: Data, orientation: CGImagePropertyOrientation) throws
      -> Blob
    {
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        CGImageSourceGetCount(source) > 0
      else {
        throw TranslationError.undecodableImage
      }
      if orientation == .up, !hasEmbeddedOrientation(source),
        let typeIdentifier = CGImageSourceGetType(source),
        let type = UTType(typeIdentifier as String),
        let mimeType = passThroughMIMETypes[type]
      {
        return Blob(mimeType: mimeType, data: data)
      }
      // `CGImageSourceCreateImageAtIndex` returns the stored pixels without applying the embedded
      // orientation, consistent with `Transcript.ImageAttachment.cgImage`.
      guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw TranslationError.undecodableImage
      }
      return try jpegBlob(for: image, orientation: orientation)
    }

    /// Creates a JPEG blob from an image, rotated to its display orientation.
    ///
    /// - Parameters:
    ///   - image: The image, with pixels stored in the given orientation.
    ///   - orientation: The display orientation of the image.
    /// - Returns: A blob containing the JPEG-encoded image.
    /// - Throws: ``TranslationError/encodingFailed`` if the image can't be rotated or encoded.
    static func jpegBlob(for image: CGImage, orientation: CGImagePropertyOrientation) throws
      -> Blob
    {
      let orientedImage = try orientedOpaqueImage(from: image, orientation: orientation)
      let data = NSMutableData()
      guard
        let destination = CGImageDestinationCreateWithData(
          data as CFMutableData,
          UTType.jpeg.identifier as CFString,
          1,
          nil
        )
      else {
        throw TranslationError.encodingFailed
      }
      let properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: jpegCompressionQuality
      ]
      CGImageDestinationAddImage(destination, orientedImage, properties as CFDictionary)
      guard CGImageDestinationFinalize(destination) else {
        throw TranslationError.encodingFailed
      }
      return Blob(mimeType: jpegMIMEType, data: data as Data)
    }

    // MARK: - Private Helpers

    /// Returns whether the image source has an embedded orientation other than `.up`.
    private static func hasEmbeddedOrientation(_ source: CGImageSource) -> Bool {
      guard
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
        let rawOrientation = properties[kCGImagePropertyOrientation] as? NSNumber
      else {
        return false
      }
      return rawOrientation.uint32Value != CGImagePropertyOrientation.up.rawValue
    }

    /// Draws an image into an opaque bitmap, applying the transform for its display orientation.
    ///
    /// Drawing into an opaque context composites any transparency onto black, matching the JPEG
    /// output of `Transcript`'s `Codable` conformance.
    ///
    /// - Parameters:
    ///   - image: The image, with pixels stored in the given orientation.
    ///   - orientation: The display orientation of the image.
    /// - Returns: An opaque image in its display orientation.
    /// - Throws: ``TranslationError/encodingFailed`` if the bitmap context can't be created.
    private static func orientedOpaqueImage(
      from image: CGImage,
      orientation: CGImagePropertyOrientation
    ) throws -> CGImage {
      let width = CGFloat(image.width)
      let height = CGFloat(image.height)
      let swapsDimensions: Bool
      switch orientation {
      case .left, .leftMirrored, .right, .rightMirrored:
        swapsDimensions = true
      default:
        swapsDimensions = false
      }
      let outputWidth = swapsDimensions ? image.height : image.width
      let outputHeight = swapsDimensions ? image.width : image.height

      let colorSpace: CGColorSpace
      if let imageColorSpace = image.colorSpace, imageColorSpace.model == .rgb {
        colorSpace = imageColorSpace
      } else if let sRGB = CGColorSpace(name: CGColorSpace.sRGB) {
        colorSpace = sRGB
      } else {
        throw TranslationError.encodingFailed
      }
      guard
        let context = CGContext(
          data: nil,
          width: outputWidth,
          height: outputHeight,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
      else {
        throw TranslationError.encodingFailed
      }

      context.concatenate(displayTransform(for: orientation, width: width, height: height))
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      guard let orientedImage = context.makeImage() else {
        throw TranslationError.encodingFailed
      }
      return orientedImage
    }

    /// Returns the transform that maps an image drawn at `(0, 0, width, height)` to its display
    /// orientation in a bottom-left-origin coordinate space.
    ///
    /// - Parameters:
    ///   - orientation: The display orientation of the image.
    ///   - width: The width of the stored image, in pixels.
    ///   - height: The height of the stored image, in pixels.
    /// - Returns: The transform to concatenate before drawing the image.
    private static func displayTransform(
      for orientation: CGImagePropertyOrientation,
      width: CGFloat,
      height: CGFloat
    ) -> CGAffineTransform {
      switch orientation {
      case .up:
        return .identity
      case .upMirrored:
        // Flip horizontally.
        return CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: width, ty: 0)
      case .down:
        // Rotate 180°.
        return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: width, ty: height)
      case .downMirrored:
        // Flip vertically.
        return CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: height)
      case .leftMirrored:
        // Transpose (reflect across the top-left to bottom-right diagonal).
        return CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: height, ty: width)
      case .right:
        // Rotate 90° clockwise.
        return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: width)
      case .rightMirrored:
        // Transverse (reflect across the top-right to bottom-left diagonal).
        return CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
      case .left:
        // Rotate 90° counterclockwise.
        return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: height, ty: 0)
      @unknown default:
        return .identity
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
