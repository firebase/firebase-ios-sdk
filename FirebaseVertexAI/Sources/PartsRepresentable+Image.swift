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
public enum ImageConversionError: Error {
  /// The image (the receiver of the call `toModelContentParts()`) was invalid.
  case invalidUnderlyingImage

  /// A valid image destination could not be allocated.
  case couldNotAllocateDestination

  /// JPEG image data conversion failed, accompanied by the original image, which may be an
  /// instance of `NSImageRep`, `UIImage`, `CGImage`, or `CIImage`.
  case couldNotConvertToJPEG(Any)
}

#if canImport(UIKit)
  /// Enables images to be representable as ``ThrowingPartsRepresentable``.
  @available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
  extension UIImage: ThrowingPartsRepresentable {
    public func tryPartsValue() throws -> [ModelContent.Part] {
      guard let data = jpegData(compressionQuality: imageCompressionQuality) else {
        throw ImageConversionError.couldNotConvertToJPEG(self)
      }
      return [ModelContent.Part.data(mimetype: "image/jpeg", data)]
    }
  }

#elseif canImport(AppKit)
  /// Enables images to be representable as ``ThrowingPartsRepresentable``.
  @available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
  extension NSImage: ThrowingPartsRepresentable {
    public func tryPartsValue() throws -> [ModelContent.Part] {
      guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw ImageConversionError.invalidUnderlyingImage
      }
      let bmp = NSBitmapImageRep(cgImage: cgImage)
      guard let data = bmp.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
      else {
        throw ImageConversionError.couldNotConvertToJPEG(bmp)
      }
      return [ModelContent.Part.data(mimetype: "image/jpeg", data)]
    }
  }
#endif

/// Enables `CGImages` to be representable as model content.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CGImage: ThrowingPartsRepresentable {
  public func tryPartsValue() throws -> [ModelContent.Part] {
    let output = NSMutableData()
    guard let imageDestination = CGImageDestinationCreateWithData(
      output, UTType.jpeg.identifier as CFString, 1, nil
    ) else {
      throw ImageConversionError.couldNotAllocateDestination
    }
    CGImageDestinationAddImage(imageDestination, self, nil)
    CGImageDestinationSetProperties(imageDestination, [
      kCGImageDestinationLossyCompressionQuality: imageCompressionQuality,
    ] as CFDictionary)
    if CGImageDestinationFinalize(imageDestination) {
      return [.data(mimetype: "image/jpeg", output as Data)]
    }
    throw ImageConversionError.couldNotConvertToJPEG(self)
  }
}

/// Enables `CIImages` to be representable as model content.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension CIImage: ThrowingPartsRepresentable {
  public func tryPartsValue() throws -> [ModelContent.Part] {
    let context = CIContext()
    let jpegData = (colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB))
      .flatMap {
        // The docs specify kCGImageDestinationLossyCompressionQuality as a supported option, but
        // Swift's type system does not allow this.
        // [kCGImageDestinationLossyCompressionQuality: imageCompressionQuality]
        context.jpegRepresentation(of: self, colorSpace: $0, options: [:])
      }
    if let jpegData = jpegData {
      return [.data(mimetype: "image/jpeg", jpegData)]
    }
    throw ImageConversionError.couldNotConvertToJPEG(self)
  }
}
