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
  import ImageIO
  import UniformTypeIdentifiers

  /// Generates and inspects images for tests without bundled resources.
  enum TestImages {
    /// A distinct, easily recognizable color used in generated test images.
    enum Color: String, CaseIterable, Sendable {
      case red
      case green
      case blue
      case yellow
      case white
      case black

      /// The sRGB components of the color.
      var components: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        switch self {
        case .red: (1, 0, 0)
        case .green: (0, 1, 0)
        case .blue: (0, 0, 1)
        case .yellow: (1, 1, 0)
        case .white: (1, 1, 1)
        case .black: (0, 0, 0)
        }
      }

      /// Returns the color closest to the given 8-bit sRGB components.
      static func nearest(red: UInt8, green: UInt8, blue: UInt8) -> Color {
        let sample = (Double(red) / 255, Double(green) / 255, Double(blue) / 255)
        return allCases.min { lhs, rhs in
          lhs.squaredDistance(to: sample) < rhs.squaredDistance(to: sample)
        } ?? .black
      }

      private func squaredDistance(to sample: (Double, Double, Double)) -> Double {
        let (red, green, blue) = components
        let deltas = [Double(red) - sample.0, Double(green) - sample.1, Double(blue) - sample.2]
        return deltas.reduce(0) { $0 + $1 * $1 }
      }
    }

    /// A simple shape drawn in black on a white background.
    enum Shape: String, CaseIterable, Sendable {
      case circle
      case square
      case triangle
    }

    /// An error thrown when a test image can't be created, encoded, or decoded.
    struct ImageError: Error, CustomStringConvertible {
      /// A description of the failure.
      let description: String
    }

    // MARK: - Creating images

    /// Creates an image filled with a single color.
    ///
    /// - Parameters:
    ///   - color: The fill color.
    ///   - width: The image width, in pixels.
    ///   - height: The image height, in pixels.
    /// - Returns: The generated image.
    static func solid(_ color: Color, width: Int = 256, height: Int = 256) throws -> CGImage {
      try draw(width: width, height: height) { context in
        fill(context, color, CGRect(x: 0, y: 0, width: width, height: height))
      }
    }

    /// Creates an image whose four quadrants are filled with different colors.
    ///
    /// - Parameters:
    ///   - topLeft: The color of the top-left quadrant.
    ///   - topRight: The color of the top-right quadrant.
    ///   - bottomLeft: The color of the bottom-left quadrant.
    ///   - bottomRight: The color of the bottom-right quadrant.
    ///   - width: The image width, in pixels.
    ///   - height: The image height, in pixels.
    /// - Returns: The generated image.
    static func quadrants(
      topLeft: Color,
      topRight: Color,
      bottomLeft: Color,
      bottomRight: Color,
      width: Int = 128,
      height: Int = 64
    ) throws -> CGImage {
      try draw(width: width, height: height) { context in
        let halfWidth = width / 2
        let halfHeight = height / 2
        // Core Graphics uses a bottom-left origin.
        fill(context, bottomLeft, CGRect(x: 0, y: 0, width: halfWidth, height: halfHeight))
        fill(context, bottomRight, CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight))
        fill(context, topLeft, CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight))
        fill(
          context, topRight,
          CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight)
        )
      }
    }

    /// Creates an image whose top and bottom halves are filled with different colors.
    ///
    /// - Parameters:
    ///   - top: The color of the top half.
    ///   - bottom: The color of the bottom half.
    ///   - size: The width and height of the image, in pixels.
    /// - Returns: The generated image.
    static func halves(top: Color, bottom: Color, size: Int = 256) throws -> CGImage {
      try quadrants(
        topLeft: top,
        topRight: top,
        bottomLeft: bottom,
        bottomRight: bottom,
        width: size,
        height: size
      )
    }

    /// Creates an image of a single large black shape centered on a white background.
    ///
    /// - Parameters:
    ///   - shape: The shape to draw.
    ///   - size: The width and height of the image, in pixels.
    /// - Returns: The generated image.
    static func shape(_ shape: Shape, size: Int = 512) throws -> CGImage {
      try draw(width: size, height: size) { context in
        fill(context, .white, CGRect(x: 0, y: 0, width: size, height: size))
        let inset = CGFloat(size) * 0.15
        let bounds = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: inset, dy: inset)
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        switch shape {
        case .circle:
          context.fillEllipse(in: bounds)
        case .square:
          context.fill(bounds)
        case .triangle:
          context.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
          context.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
          context.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
          context.closePath()
          context.fillPath()
        }
      }
    }

    // MARK: - Encoding and decoding

    /// Encodes an image in the given format.
    ///
    /// - Parameters:
    ///   - image: The image to encode.
    ///   - type: The image format, such as `.png` or `.jpeg`.
    ///   - orientation: An optional orientation to embed in the image metadata.
    /// - Returns: The encoded image data.
    static func encode(
      _ image: CGImage,
      as type: UTType,
      orientation: CGImagePropertyOrientation? = nil
    ) throws -> Data {
      let data = NSMutableData()
      guard
        let destination = CGImageDestinationCreateWithData(
          data as CFMutableData, type.identifier as CFString, 1, nil
        )
      else {
        throw ImageError(description: "Can't create an image destination for \(type.identifier).")
      }
      var properties: [CFString: Any] = [:]
      if let orientation {
        properties[kCGImagePropertyOrientation] = orientation.rawValue
      }
      CGImageDestinationAddImage(destination, image, properties as CFDictionary)
      guard CGImageDestinationFinalize(destination) else {
        throw ImageError(description: "Can't encode the image as \(type.identifier).")
      }
      return data as Data
    }

    /// Writes data to a new uniquely named file in the temporary directory.
    ///
    /// - Parameters:
    ///   - data: The file contents.
    ///   - pathExtension: The file extension, such as `png`.
    /// - Returns: The URL of the new file.
    static func writeTemporaryFile(_ data: Data, pathExtension: String) throws -> URL {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("GeminiLanguageModelTests-\(UUID().uuidString)")
        .appendingPathExtension(pathExtension)
      try data.write(to: url)
      return url
    }

    /// Decodes image data, without applying any embedded orientation.
    ///
    /// - Parameter data: The encoded image data.
    /// - Returns: The decoded image.
    static func decode(_ data: Data) throws -> CGImage {
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
      else {
        throw ImageError(description: "Can't decode the image data.")
      }
      return image
    }

    /// Returns the type identifier of encoded image data.
    ///
    /// - Parameter data: The encoded image data.
    /// - Returns: The detected image type, or `nil` if it can't be determined.
    static func type(of data: Data) -> UTType? {
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let identifier = CGImageSourceGetType(source)
      else {
        return nil
      }
      return UTType(identifier as String)
    }

    /// Returns the orientation embedded in encoded image data, if any.
    ///
    /// - Parameter data: The encoded image data.
    /// - Returns: The raw embedded orientation value, or `nil` if there is none.
    static func embeddedOrientation(of data: Data) -> UInt32? {
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
        let orientation = properties[kCGImagePropertyOrientation] as? NSNumber
      else {
        return nil
      }
      return orientation.uint32Value
    }

    /// Returns the colors at the centers of an image's four quadrants.
    ///
    /// - Parameter image: The image to sample.
    /// - Returns: The nearest ``Color`` at the center of each quadrant.
    static func quadrantColors(
      of image: CGImage
    ) throws -> (topLeft: Color, topRight: Color, bottomLeft: Color, bottomRight: Color) {
      let width = image.width
      let height = image.height
      let pixels = try rgbaPixels(of: image)
      func color(atX x: Int, y: Int) -> Color {
        let offset = (y * width + x) * 4
        return Color.nearest(
          red: pixels[offset], green: pixels[offset + 1], blue: pixels[offset + 2])
      }
      return (
        topLeft: color(atX: width / 4, y: height / 4),
        topRight: color(atX: width * 3 / 4, y: height / 4),
        bottomLeft: color(atX: width / 4, y: height * 3 / 4),
        bottomRight: color(atX: width * 3 / 4, y: height * 3 / 4)
      )
    }

    // MARK: - Private helpers

    private static func draw(
      width: Int,
      height: Int,
      _ body: (CGContext) -> Void
    ) throws -> CGImage {
      guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
        let context = CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      else {
        throw ImageError(description: "Can't create a \(width)x\(height) bitmap context.")
      }
      body(context)
      guard let image = context.makeImage() else {
        throw ImageError(description: "Can't create an image from the bitmap context.")
      }
      return image
    }

    private static func fill(_ context: CGContext, _ color: Color, _ rect: CGRect) {
      let (red, green, blue) = color.components
      context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
      context.fill(rect)
    }

    /// Returns RGBA pixel data for an image, with the first row at the top of the image.
    private static func rgbaPixels(of image: CGImage) throws -> [UInt8] {
      let width = image.width
      let height = image.height
      var pixels = [UInt8](repeating: 0, count: width * height * 4)
      guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        throw ImageError(description: "Can't create an sRGB color space.")
      }
      let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard
          let context = CGContext(
            data: buffer.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          )
        else {
          return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
      }
      guard drawn else {
        throw ImageError(description: "Can't create a bitmap context to read pixels.")
      }
      return pixels
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
