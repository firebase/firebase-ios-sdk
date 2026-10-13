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

  #if canImport(CoreImage)
    import CoreImage
  #endif  // canImport(CoreImage)

  /// Translates Foundation Models image attachments into Gemini API part data.
  ///
  /// Images are sent to Gemini as inline data:
  ///
  /// - File URLs whose bytes are already in a Gemini-supported format (PNG, JPEG, WebP, HEIC, or
  ///   HEIF) and that need no rotation are sent unchanged.
  /// - All other images (`CGImage`, `CIImage`, and `CVPixelBuffer` sources, other file formats,
  ///   and images with a non-`.up` orientation) are rotated to their display orientation and
  ///   re-encoded as JPEG, matching the format used by `Transcript`'s `Codable` conformance.
  ///
  /// For files that contain several images, the first image is used, matching
  /// `Transcript.ImageAttachment`, which reads both its orientation and its pixels from the first
  /// image.
  ///
  /// Non-file URLs aren't supported.
  ///
  /// Images are encoded using only CoreGraphics, ImageIO, and UniformTypeIdentifiers so that the
  /// translation works on every platform that supports Foundation Models, including watchOS,
  /// which lacks CoreImage. Where CoreImage is available, it's only used to reject `CIImage`
  /// sources that can't be rendered.
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
      ///
      /// URLs other than file URLs are described by their scheme only, since the full URL may be
      /// very long (e.g., a `data:` URL) or contain credentials (e.g., a signed URL).
      var description: String {
        switch self {
        case .unsupportedURL(let url):
          let scheme = url.scheme.map { "\"\($0)\"" } ?? "no"
          return
            "Image attachments are only supported for file URLs, not URLs with \(scheme) scheme."
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
    /// - Throws: A ``TranslationError`` if the attachment references a non-file URL, or if the
    ///   image can't be read, decoded, or encoded.
    static func partData(
      for attachment: Transcript.ImageAttachment
    ) throws(TranslationError) -> Part.PartData {
      // Reading `orientation` is safe for every attachment source. Reading `cgImage` isn't: it
      // traps for URL-backed attachments whose image couldn't be loaded (e.g., `gs://` URLs), so
      // URL-backed attachments are loaded from their file bytes instead.
      let orientation = attachment.orientation
      guard let url = attachment.url else {
        #if canImport(CoreImage)
          // Reading `cgImage` also traps for `CIImage` sources with an empty or infinite extent,
          // such as `CIImage.empty()` or an uncropped `CIImage(color:)`.
          let extent = attachment.ciImage.extent
          guard !extent.isEmpty, !extent.isInfinite else {
            throw .undecodableImage
          }
        #endif  // canImport(CoreImage)
        return try .inlineData(jpegBlob(for: attachment.cgImage, orientation: orientation))
      }
      guard url.isFileURL else {
        throw .unsupportedURL(url)
      }
      return try .inlineData(blob(forFileAt: url, orientation: orientation))
    }

    // MARK: - Private Helpers

    /// Creates a blob from the image file at the given URL.
    ///
    /// - Parameters:
    ///   - url: The file URL of the image.
    ///   - orientation: The display orientation of the image, as resolved by
    ///     `Transcript.ImageAttachment`.
    /// - Returns: A blob containing either the original file bytes or a re-encoded JPEG.
    /// - Throws: A ``TranslationError`` if the file can't be read, decoded, or encoded.
    private static func blob(
      forFileAt url: URL,
      orientation: CGImagePropertyOrientation
    ) throws(TranslationError) -> Blob {
      let data: Data
      do {
        data = try Data(contentsOf: url)
      } catch {
        throw .unreadableFile(url)
      }
      return try blob(forImageData: data, orientation: orientation)
    }

    /// Creates a blob from encoded image data.
    ///
    /// The data is sent unchanged when it's in a pass-through format, its primary image is its
    /// first image, `orientation` is `.up`, and the first image has no embedded non-default
    /// orientation. Otherwise, the first image is decoded, rotated to its display orientation, and
    /// re-encoded as JPEG.
    ///
    /// `orientation` must be resolved the way `Transcript.ImageAttachment` resolves it: an
    /// explicit orientation if one was given, or else the first image's embedded orientation. An
    /// `orientation` of `.up` for an image with a different embedded orientation is treated as an
    /// explicit override.
    ///
    /// - Parameters:
    ///   - data: The encoded image data.
    ///   - orientation: The display orientation of the first image.
    /// - Returns: A blob containing either `data` or a re-encoded JPEG.
    /// - Throws: A ``TranslationError`` if the data can't be decoded or encoded.
    private static func blob(
      forImageData data: Data,
      orientation: CGImagePropertyOrientation
    ) throws(TranslationError) -> Blob {
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        CGImageSourceGetCount(source) > 0
      else {
        throw .undecodableImage
      }
      // `Transcript.ImageAttachment` reads both its orientation and its pixels from the first
      // image, even when a file such as a HEIC designates a different primary image. The first
      // image is used here too, and files are only passed through when Gemini would decode the
      // same image.
      let index = 0
      if orientation == .up, CGImageSourceGetPrimaryImageIndex(source) == index,
        !hasEmbeddedOrientation(source, at: index),
        let typeIdentifier = CGImageSourceGetType(source),
        let type = UTType(typeIdentifier as String),
        let mimeType = passThroughMIMETypes[type]
      {
        return Blob(mimeType: mimeType, data: data)
      }
      // `CGImageSourceCreateImageAtIndex` returns the stored pixels without applying the embedded
      // orientation, consistent with `Transcript.ImageAttachment.cgImage`.
      guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
        throw .undecodableImage
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
    private static func jpegBlob(
      for image: CGImage,
      orientation: CGImagePropertyOrientation
    ) throws(TranslationError) -> Blob {
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
        throw .encodingFailed
      }
      let properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: jpegCompressionQuality
      ]
      CGImageDestinationAddImage(destination, orientedImage, properties as CFDictionary)
      guard CGImageDestinationFinalize(destination) else {
        throw .encodingFailed
      }
      return Blob(mimeType: jpegMIMEType, data: data as Data)
    }

    /// Returns whether an image in the source has an embedded orientation other than `.up`.
    ///
    /// - Parameters:
    ///   - source: The image source to inspect.
    ///   - index: The index of the image in the source.
    /// - Returns: `true` if the image's metadata specifies a non-default orientation.
    private static func hasEmbeddedOrientation(_ source: CGImageSource, at index: Int) -> Bool {
      guard
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
          as? [CFString: Any],
        let rawOrientation = properties[kCGImagePropertyOrientation] as? NSNumber
      else {
        return false
      }
      return rawOrientation.uint32Value != CGImagePropertyOrientation.up.rawValue
    }

    /// Draws an image into an opaque bitmap, applying the transform for its display orientation.
    ///
    /// The bitmap is filled with black before drawing, so any transparency is composited onto
    /// black, matching the JPEG output of `Transcript`'s `Codable` conformance.
    ///
    /// - Parameters:
    ///   - image: The image, with pixels stored in the given orientation.
    ///   - orientation: The display orientation of the image.
    /// - Returns: An opaque image in its display orientation.
    /// - Throws: ``TranslationError/encodingFailed`` if the bitmap context can't be created.
    private static func orientedOpaqueImage(
      from image: CGImage,
      orientation: CGImagePropertyOrientation
    ) throws(TranslationError) -> CGImage {
      let width = CGFloat(image.width)
      let height = CGFloat(image.height)
      let swapsDimensions: Bool
      switch orientation {
      case .up, .upMirrored, .down, .downMirrored:
        swapsDimensions = false
      case .left, .leftMirrored, .right, .rightMirrored:
        swapsDimensions = true
      }
      let outputWidth = swapsDimensions ? image.height : image.width
      let outputHeight = swapsDimensions ? image.width : image.height

      let context = try makeOpaqueContext(
        width: outputWidth,
        height: outputHeight,
        preferredColorSpace: image.colorSpace
      )
      context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
      context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
      context.concatenate(displayTransform(for: orientation, width: width, height: height))
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      guard let orientedImage = context.makeImage() else {
        throw .encodingFailed
      }
      return orientedImage
    }

    /// Creates an 8-bit opaque RGB bitmap context.
    ///
    /// The preferred color space is used when it's a standard-range, non-HDR RGB color space (such
    /// as sRGB or Display P3). Otherwise, including for extended-range and HDR color spaces, which
    /// can't be represented in an 8-bit JPEG, sRGB is used.
    ///
    /// - Parameters:
    ///   - width: The width of the context, in pixels.
    ///   - height: The height of the context, in pixels.
    ///   - preferredColorSpace: The color space of the source image, if any.
    /// - Returns: The bitmap context.
    /// - Throws: ``TranslationError/encodingFailed`` if no bitmap context can be created.
    private static func makeOpaqueContext(
      width: Int,
      height: Int,
      preferredColorSpace: CGColorSpace?
    ) throws(TranslationError) -> CGContext {
      func makeContext(_ colorSpace: CGColorSpace) -> CGContext? {
        CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
      }

      if let preferredColorSpace, preferredColorSpace.model == .rgb,
        !CGColorSpaceUsesExtendedRange(preferredColorSpace), !preferredColorSpace.isHDR(),
        let context = makeContext(preferredColorSpace)
      {
        return context
      }
      guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB), let context = makeContext(sRGB)
      else {
        throw .encodingFailed
      }
      return context
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
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
