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
#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

@testable import FirebaseAI

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension PartsRepresentableTests {
  func testMixedParts() throws {
    let text = "This is a test"
    let data = try XCTUnwrap("This is some data".data(using: .utf8))
    let inlineData = InlineDataPart(data: data, mimeType: "text/plain")

    let parts: [any PartsRepresentable] = [text, inlineData]
    let modelContent = ModelContent(parts: parts)

    XCTAssertEqual(modelContent.parts.count, 2)
    let textPart = try XCTUnwrap(modelContent.parts[0] as? TextPart)
    XCTAssertEqual(textPart.text, text)
    let dataPart = try XCTUnwrap(modelContent.parts[1] as? InlineDataPart)
    XCTAssertEqual(dataPart, inlineData)
  }

  #if canImport(UIKit) && !os(visionOS)
    func testMixedParts_withImage() throws {
      let text = "This is a test"
      let image = try XCTUnwrap(UIImage(systemName: "star"))
      let parts: [any PartsRepresentable] = [text, image]
      let modelContent = ModelContent(parts: parts)

      XCTAssertEqual(modelContent.parts.count, 2)
      let textPart = try XCTUnwrap(modelContent.parts[0] as? TextPart)
      XCTAssertEqual(textPart.text, text)
      let imagePart = try XCTUnwrap(modelContent.parts[1] as? InlineDataPart)
      XCTAssertEqual(imagePart.mimeType, "image/jpeg")
      XCTAssertFalse(imagePart.data.isEmpty)
    }

  #elseif canImport(AppKit)
    func testMixedParts_withImage() throws {
      let text = "This is a test"
      let coreImage = CIImage(color: CIColor.blue)
        .cropped(to: CGRect(origin: CGPoint.zero, size: CGSize(width: 16, height: 16)))
      let rep = NSCIImageRep(ciImage: coreImage)
      let image = NSImage(size: rep.size)
      image.addRepresentation(rep)

      let parts: [any PartsRepresentable] = [text, image]
      let modelContent = ModelContent(parts: parts)

      XCTAssertEqual(modelContent.parts.count, 2)
      let textPart = try XCTUnwrap(modelContent.parts[0] as? TextPart)
      XCTAssertEqual(textPart.text, text)
      let imagePart = try XCTUnwrap(modelContent.parts[1] as? InlineDataPart)
      XCTAssertEqual(imagePart.mimeType, "image/jpeg")
      XCTAssertFalse(imagePart.data.isEmpty)
    }
  #endif
}
