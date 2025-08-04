// Copyright 2025 Google LLC
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

import CoreGraphics
import Foundation
import ImageIO

/// A reference to a mask for inpainting.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ImagenMaskReference: ImagenReferenceImage, Encodable {
  /// The mask data.
  public let data: Data

  public init(data: Data) {
    self.data = data
  }

  enum CodingKeys: String, CodingKey {
    case data = "bytesBase64Encoded"
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(data.base64EncodedString(), forKey: .data)
  }

  static func generateMaskAndPadForOutpainting(image: ImagenInlineImage,
                                               newDimensions: Dimensions,
                                               newPosition: ImagenImagePlacement) throws
    -> [ImagenReferenceImage] {
    guard let cgImage = CGImage.fromData(image.data) else {
      throw NSError(domain: "com.google.firebase.ai", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create image from data."])
    }

    let originalWidth = cgImage.width
    let originalHeight = cgImage.height

    guard newDimensions.width >= originalWidth, newDimensions.height >= originalHeight else {
      throw NSError(domain: "com.google.firebase.ai", code: 0, userInfo: [NSLocalizedDescriptionKey: "New dimensions must be larger than the original image."])
    }

    let offsetX: Int
    let offsetY: Int

    switch newPosition {
    case .topLeft:
      offsetX = 0
      offsetY = 0
    case .topCenter:
      offsetX = (newDimensions.width - originalWidth) / 2
      offsetY = 0
    case .topRight:
      offsetX = newDimensions.width - originalWidth
      offsetY = 0
    case .middleLeft:
      offsetX = 0
      offsetY = (newDimensions.height - originalHeight) / 2
    case .center:
      offsetX = (newDimensions.width - originalWidth) / 2
      offsetY = (newDimensions.height - originalHeight) / 2
    case .middleRight:
      offsetX = newDimensions.width - originalWidth
      offsetY = (newDimensions.height - originalHeight) / 2
    case .bottomLeft:
      offsetX = 0
      offsetY = newDimensions.height - originalHeight
    case .bottomCenter:
      offsetX = (newDimensions.width - originalWidth) / 2
      offsetY = newDimensions.height - originalHeight
    case .bottomRight:
      offsetX = newDimensions.width - originalWidth
      offsetY = newDimensions.height - originalHeight
    case let .custom(x, y):
      offsetX = x
      offsetY = y
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    // Create padded image
    guard let paddedContext = CGContext(data: nil, width: newDimensions.width, height: newDimensions.height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else {
      throw NSError(domain: "com.google.firebase.ai", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create padded image context."])
    }
    paddedContext.draw(cgImage, in: CGRect(x: offsetX, y: offsetY, width: originalWidth, height: originalHeight))
    guard let paddedCGImage = paddedContext.makeImage(), let paddedImageData = paddedCGImage.toData() else {
      throw NSError(domain: "com.google.firebase.ai", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not get padded image data."])
    }

    // Create mask
    guard let maskContext = CGContext(data: nil, width: newDimensions.width, height: newDimensions.height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
      throw NSError(domain: "com.google.firebase.ai", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not create mask context."])
    }
    maskContext.setFillColor(gray: 1.0, alpha: 1.0)
    maskContext.fill(CGRect(x: 0, y: 0, width: newDimensions.width, height: newDimensions.height))
    maskContext.setFillColor(gray: 0.0, alpha: 1.0)
    maskContext.fill(CGRect(x: offsetX, y: offsetY, width: originalWidth, height: originalHeight))
    guard let maskCGImage = maskContext.makeImage(), let maskData = maskCGImage.toData() else {
      throw NSError(domain: "com.google.firebase.ai", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not get mask data."])
    }

    return [ImagenRawImage(data: paddedImageData), ImagenMaskReference(data: maskData)]
  }
}

extension CGImage {
    static func fromData(_ data: Data) -> CGImage? {
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    func toData() -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}