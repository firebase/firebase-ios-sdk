// Copyright 2024 Google LLC
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

import UniformTypeIdentifiers
#if canImport(UIKit)
  import UIKit // For UIImage extensions.
#elseif canImport(AppKit)
  import AppKit // For NSImage extensions.
#endif

private let imageCompressionQuality: CGFloat = 0.8

/// An enum describing failures that can occur when converting image types to model content data.
/// For some image types like `CIImage`, creating valid model content requires creating a JPEG
/// representation of the image that may not yet exist, which may be computationally expensive.
enum ImageConversionError: Error {
  /// The image (the receiver of the call `toModelContentParts()`) was invalid.
  case invalidUnderlyingImage

  /// A valid image destination could not be allocated.
  case couldNotAllocateDestination

  /// JPEG image data conversion failed.
  case couldNotConvertToJPEG
}

#if canImport(UIKit)
  /// Enables images to be representable as ``PartsRepresentable``.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension UIImage: PartsRepresentable {
    public var partsValue: [any Part] {
      guard let data = jpegData(compressionQuality: imageCompressionQuality) else {
        return [ErrorPart(ImageConversionError.couldNotConvertToJPEG)]
      }
      return [InlineDataPart(data: data, mimeType: "image/jpeg")]
    }
  }

#elseif canImport(AppKit)
  /// Enables images to be representable as ``PartsRepresentable``.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
  extension NSImage: PartsRepresentable {
    public var partsValue: [any Part] {
      guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return [ErrorPart(ImageConversionError.invalidUnderlyingImage)]
      }
      let bmp = NSBitmapImageRep(cgImage: cgImage)
      guard let data = bmp.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
      else {
        return [ErrorPart(ImageConversionError.couldNotConvertToJPEG)]
      }
      return [InlineDataPart(data: data, mimeType: "image/jpeg")]
    }
  }
#endif

#if !os(watchOS) // This code does not build on watchOS.
  /// Enables `CGImages` to be representable as model content.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
  extension CGImage: PartsRepresentable {
    public var partsValue: [any Part] {
      let output = NSMutableData()
      guard let imageDestination = CGImageDestinationCreateWithData(
        output, UTType.jpeg.identifier as CFString, 1, nil
      ) else {
        return [ErrorPart(ImageConversionError.couldNotAllocateDestination)]
      }
      CGImageDestinationAddImage(imageDestination, self, nil)
      CGImageDestinationSetProperties(imageDestination, [
        kCGImageDestinationLossyCompressionQuality: imageCompressionQuality,
      ] as CFDictionary)
      if CGImageDestinationFinalize(imageDestination) {
        return [InlineDataPart(data: output as Data, mimeType: "image/jpeg")]
      }
      return [ErrorPart(ImageConversionError.couldNotConvertToJPEG)]
    }
  }
#endif // !os(watchOS)

#if canImport(CoreImage)
  /// Enables `CIImages` to be representable as model content.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
  extension CIImage: PartsRepresentable {
    public var partsValue: [any Part] {
      let context = CIContext()
      let jpegData = (colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB))
        .flatMap {
          // The docs specify kCGImageDestinationLossyCompressionQuality as a supported option, but
          // Swift's type system does not allow this.
          // [kCGImageDestinationLossyCompressionQuality: imageCompressionQuality]
          context.jpegRepresentation(of: self, colorSpace: $0, options: [:])
        }
      if let jpegData = jpegData {
        return [InlineDataPart(data: jpegData, mimeType: "image/jpeg")]
      }
      return [ErrorPart(ImageConversionError.couldNotConvertToJPEG)]
    }
  }
#endif // canImport(CoreImage)
