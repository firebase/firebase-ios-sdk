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
  import Testing

  @testable import FoundationModelsFake

  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  #if canImport(CoreGraphics)
    import CoreGraphics
  #endif
  #if canImport(ImageIO)
    import ImageIO
  #endif

  @Suite("Attachment Tests")
  struct AttachmentTests {
    @Test
    func urlAttachmentInitialization() throws {
      let url = try #require(URL(string: "https://example.com/test.jpg"))

      let attachment = Attachment(imageURL: url, orientation: .up)

      let prompt = attachment.promptRepresentation
      #expect(prompt.components.count == 1)
      guard case .attachment(let a) = prompt.components.first else {
        Issue.record("Expected attachment component")
        return
      }
      guard case .image(let img) = a.content else {
        Issue.record("Expected image content")
        return
      }
      #expect(img.url == url)
      #expect(img.orientation == .up)
      #expect(a.label == nil)
    }

    @Test
    func attachmentLabel() throws {
      let url = try #require(URL(string: "https://example.com/test.jpg"))

      let attachment = Attachment(imageURL: url).label("featured-image")

      let prompt = attachment.promptRepresentation
      guard case .attachment(let a) = prompt.components.first else {
        Issue.record("Expected attachment component")
        return
      }
      #expect(a.label == "featured-image")
    }

    @Test
    func attachmentInstructionsRepresentation() throws {
      let url = try #require(URL(string: "https://example.com/instructions.png"))

      let attachment = Attachment(imageURL: url).label("diagram")
      let instructions = attachment.instructionsRepresentation

      #expect(instructions.components.count == 1)
      guard case .attachment(let a) = instructions.components.first else {
        Issue.record("Expected attachment component")
        return
      }
      #expect(a.label == "diagram")
    }

    @Test
    func imageAttachmentContentEquality() throws {
      let url1 = try #require(URL(string: "https://example.com/1.png"))
      let url2 = try #require(URL(string: "https://example.com/2.png"))

      let contentA = ImageAttachmentContent(url: url1, orientation: .up)
      let contentB = ImageAttachmentContent(url: url1, orientation: .up)
      let contentC = ImageAttachmentContent(url: url2, orientation: .up)
      let contentD = ImageAttachmentContent(url: url1, orientation: .down)

      #expect(contentA == contentB)
      #expect(contentA != contentC)
      #expect(contentA != contentD)
    }

    #if canImport(CoreGraphics)
      @Test
      func cgImageAttachmentInitialization() {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
          let context = unsafe CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ),
          let cgImage = context.makeImage()
        else {
          Issue.record("Failed to create test CGImage")
          return
        }

        let attachment = Attachment(cgImage, orientation: .right)
        let prompt = attachment.promptRepresentation

        guard case .attachment(let a) = prompt.components.first else {
          Issue.record("Expected attachment component")
          return
        }
        guard case .image(let img) = a.content else {
          Issue.record("Expected image content")
          return
        }
        #expect(img.orientation == .right)
        #expect(img.cgImage != nil)
      }
    #endif
  }
#endif  // compiler(>=6.4)
