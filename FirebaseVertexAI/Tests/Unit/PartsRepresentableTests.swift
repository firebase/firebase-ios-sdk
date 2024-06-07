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

import CoreGraphics
import CoreImage
import FirebaseVertexAI
import XCTest
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
final class PartsRepresentableTests: XCTestCase {
  func testModelContentFromCGImageIsNotEmpty() throws {
    // adapted from https://forums.swift.org/t/creating-a-cgimage-from-color-array/18634/2
    var srgbArray = [UInt32](repeating: 0xFFFF_FFFF, count: 8 * 8)
    let image = srgbArray.withUnsafeMutableBytes { ptr -> CGImage in
      let ctx = CGContext(
        data: ptr.baseAddress,
        width: 8,
        height: 8,
        bitsPerComponent: 8,
        bytesPerRow: 4 * 8,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue +
          CGImageAlphaInfo.premultipliedFirst.rawValue
      )!
      return ctx.makeImage()!
    }
    let modelContent = try image.tryPartsValue()
    XCTAssert(modelContent.count > 0, "Expected non-empty model content for CGImage: \(image)")
  }

  func testModelContentFromCIImageIsNotEmpty() throws {
    let image = CIImage(color: CIColor.red)
      .cropped(to: CGRect(origin: CGPointZero, size: CGSize(width: 16, height: 16)))
    let modelContent = try image.tryPartsValue()
    XCTAssert(modelContent.count > 0, "Expected non-empty model content for CGImage: \(image)")
  }

  func testModelContentFromInvalidCIImageThrows() throws {
    let image = CIImage.empty()
    do {
      let _ = try image.tryPartsValue()
    } catch {
      guard let imageError = (error as? ImageConversionError) else {
        XCTFail("Got unexpected error type: \(error)")
        return
      }
      switch imageError {
      case let .couldNotConvertToJPEG(source):
        // String(describing:) works around a type error.
        XCTAssertEqual(String(describing: source), String(describing: image))
        return
      case _:
        XCTFail("Expected image conversion error, got \(imageError) instead")
        return
      }
    }
    XCTFail("Expected model content from invlaid image to error")
  }

  #if canImport(UIKit)
    func testModelContentFromInvalidUIImageThrows() {
      print("Instantiating UIImage.")
      let image = UIImage()
      do {
        print("Getting image parts.")
        _ = try image.tryPartsValue()
        XCTFail("Expected ImageConversionError.couldNotConvertToJPEG; no error.")
      } catch let ImageConversionError.couldNotConvertToJPEG(source as UIImage) {
        print("Checking image equality.")
        XCTAssertEqual(source, image)
      } catch {
        XCTFail("Expected ImageConversionError.couldNotConvertToJPEG; error thrown: \(error)")
      }
      print("Done testModelContentFromInvalidUIImageThrows.")
    }

    func testModelContentFromUIImageIsNotEmpty() {
      print("Creating UIImage with systemName.")
      guard let image = UIImage(systemName: "photo") else {
        XCTFail("Failed to create UIImage with system name.")
        return
      }
      print("Getting image parts.")
      let modelContent: [ModelContent.Part]
      do {
        modelContent = try image.tryPartsValue()
        print("Got image parts.")
      } catch {
        XCTFail("Getting image parts failed with error: \(error)")
        return
      }
      print("Checking content part count.")
      XCTAssertEqual(
        modelContent.count,
        1,
        "Expected non-empty model content for UIImage: \(image)"
      )
      print("Done testModelContentFromUIImageIsNotEmpty.")
    }

  #elseif canImport(AppKit)
    func testModelContentFromNSImageIsNotEmpty() throws {
      let coreImage = CIImage(color: CIColor.red)
        .cropped(to: CGRect(origin: CGPointZero, size: CGSize(width: 16, height: 16)))
      let rep = NSCIImageRep(ciImage: coreImage)
      let image = NSImage(size: rep.size)
      image.addRepresentation(rep)
      let modelContent = try image.tryPartsValue()
      XCTAssert(modelContent.count > 0, "Expected non-empty model content for NSImage: \(image)")
    }

    func testModelContentFromInvalidNSImageThrows() throws {
      let image = NSImage()
      do {
        _ = try image.tryPartsValue()
      } catch {
        guard let imageError = (error as? ImageConversionError) else {
          XCTFail("Got unexpected error type: \(error)")
          return
        }
        switch imageError {
        case .invalidUnderlyingImage:
          // Pass
          return
        case _:
          XCTFail("Expected image conversion error, got \(imageError) instead")
          return
        }
      }
      XCTFail("Expected model content from invlaid image to error")
    }
  #endif
}
