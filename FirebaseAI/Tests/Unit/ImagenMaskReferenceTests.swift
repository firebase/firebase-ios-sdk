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

import XCTest

@testable import FirebaseAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class ImagenMaskReferenceTests: XCTestCase {
  func testGenerateMaskAndPadForOutpainting() throws {
    // Setup
    let originalWidth = 100
    let originalHeight = 100
    let newWidth = 200
    let newHeight = 200
    let newDimensions = Dimensions(width: newWidth, height: newHeight)
    let image = ImagenInlineImage(
      mimeType: "dummy-mime",
      data: createDummyImageData(width: originalWidth, height: originalHeight)
    )

    // Act
    let referenceImages = try ImagenMaskReference.generateMaskAndPadForOutpainting(
      image: image,
      newDimensions: newDimensions,
      newPosition: .center
    )

    // Assert
    XCTAssertEqual(referenceImages.count, 2)

    let paddedImage = try XCTUnwrap(referenceImages[0] as? ImagenRawImage)
    let mask = try XCTUnwrap(referenceImages[1] as? ImagenMaskReference)

    let paddedCGImage = try XCTUnwrap(CGImage.fromData(paddedImage.data))
    XCTAssertEqual(paddedCGImage.width, newWidth)
    XCTAssertEqual(paddedCGImage.height, newHeight)

    let maskCGImage = try XCTUnwrap(CGImage.fromData(mask.data))
    XCTAssertEqual(maskCGImage.width, newWidth)
    XCTAssertEqual(maskCGImage.height, newHeight)
  }

  func testGenerateMaskAndPadForOutpainting_invalidData() {
    // Setup
    let newDimensions = Dimensions(width: 200, height: 200)
    let image = ImagenInlineImage(mimeType: "dummy-mime", data: Data())

    // Act & Assert
    XCTAssertThrowsError(try ImagenMaskReference.generateMaskAndPadForOutpainting(
      image: image,
      newDimensions: newDimensions,
      newPosition: .center
    )) { error in
      XCTAssertEqual(error as? ImagenMaskReference.OutpaintingError, .invalidImageData)
    }
  }

  func testGenerateMaskAndPadForOutpainting_dimensionsTooSmall() {
    // Setup
    let newDimensions = Dimensions(width: 50, height: 50)
    let image = ImagenInlineImage(
      mimeType: "dummy-mime",
      data: createDummyImageData(width: 100, height: 100)
    )

    // Act & Assert
    XCTAssertThrowsError(try ImagenMaskReference.generateMaskAndPadForOutpainting(
      image: image,
      newDimensions: newDimensions,
      newPosition: .center
    )) { error in
      XCTAssertEqual(error as? ImagenMaskReference.OutpaintingError, .dimensionsTooSmall)
    }
  }

  private func createDummyImageData(width: Int, height: Int) -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: bitmapInfo
    )!
    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let cgImage = context.makeImage()!
    return cgImage.toData()!
  }
}
