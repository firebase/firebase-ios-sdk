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
  #if canImport(FoundationEssentials)
    public import FoundationEssentials
  #else
    public import Foundation
  #endif

  #if canImport(CoreGraphics)
    public import CoreGraphics
  #endif
  #if canImport(CoreImage)
    public import CoreImage
  #endif
  #if canImport(CoreVideo)
    public import CoreVideo
  #endif
  #if canImport(ImageIO)
    public import ImageIO
  #endif

  /// An attachment payload containing content such as image or data media.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`Attachment`](https://developer.apple.com/documentation/foundationmodels/attachment).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct Attachment<Content> {
    /// The underlying content of this attachment.
    internal var content: Content

    /// An optional label identifying this attachment.
    internal var label: String?

    /// Creates an attachment wrapping content.
    internal init(content: Content, label: String? = nil) {
      self.content = content
      self.label = label
    }
  }

  extension Attachment {
    /// Returns a copy of this attachment with the specified label.
    ///
    /// - Parameter label: The label to identify the attachment.
    /// - Returns: An attachment with the updated label.
    public func label(_ label: String) -> Attachment<Content> {
      var copy = self
      copy.label = label
      return copy
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Attachment: PromptRepresentable, InstructionsRepresentable {
    /// A prompt representation containing this attachment.
    public var promptRepresentation: Prompt {
      if let imageContent = content as? ImageAttachmentContent {
        return Prompt(components: [
          .attachment(
            Prompt.Attachment(
              content: .image(imageContent),
              label: label
            )
          )
        ])
      }
      #if compiler(>=6.4.2)
        if let dataContent = content as? any DataAttachmentRepresentable {
          return Prompt(components: [
            .attachment(
              Prompt.Attachment(
                content: .data(dataContent.transcriptRepresentation),
                label: label
              )
            )
          ])
        }
      #endif  // compiler(>=6.4.2)
      return Prompt()
    }

    /// An instructions representation containing this attachment.
    public var instructionsRepresentation: Instructions {
      if let imageContent = content as? ImageAttachmentContent {
        return Instructions(components: [
          .attachment(
            Instructions.Attachment(
              content: .image(imageContent),
              label: label
            )
          )
        ])
      }
      #if compiler(>=6.4.2)
        if let dataContent = content as? any DataAttachmentRepresentable {
          return Instructions(components: [
            .attachment(
              Instructions.Attachment(
                content: .data(dataContent.transcriptRepresentation),
                label: label
              )
            )
          ])
        }
      #endif  // compiler(>=6.4.2)
      return Instructions()
    }
  }

  #if compiler(>=6.4.2)
    extension Attachment where Content: DataAttachmentRepresentable {
      /// Creates an attachment wrapping data content.
      ///
      /// - Parameter content: The data attachment content to wrap.
      @available(iOS 27.2, macOS 27.2, visionOS 27.2, watchOS 27.2, *)
      @available(tvOS, unavailable)
      public init(_ content: Content) {
        self.init(content: content)
      }
    }
  #endif  // compiler(>=6.4.2)

  /// The underlying image content stored in an attachment.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`ImageAttachmentContent`](https://developer.apple.com/documentation/foundationmodels/imageattachmentcontent).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public struct ImageAttachmentContent: Sendable, Equatable {
    /// The URL of the image, if backed by a file or remote asset.
    internal var url: URL?

    /// The display orientation of the image.
    internal var orientation: CGImagePropertyOrientation?

    #if canImport(CoreGraphics)
      /// The Core Graphics representation of the image.
      internal var cgImage: CGImage?
    #endif
    #if canImport(CoreImage)
      /// The Core Image representation of the image.
      internal var ciImage: CIImage?
    #endif
    #if canImport(CoreVideo)
      /// The Core Video pixel buffer representation of the image.
      nonisolated(unsafe) internal var pixelBuffer: CVPixelBuffer?
    #endif

    /// Creates image attachment content from a URL and orientation.
    internal init(
      url: URL? = nil,
      orientation: CGImagePropertyOrientation? = nil
    ) {
      self.url = url
      self.orientation = orientation
    }

    #if canImport(CoreGraphics)
      /// Creates image attachment content from a Core Graphics image.
      internal init(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation? = nil
      ) {
        self.cgImage = cgImage
        self.orientation = orientation
      }
    #endif

    #if canImport(CoreImage)
      /// Creates image attachment content from a Core Image image.
      internal init(
        ciImage: CIImage,
        orientation: CGImagePropertyOrientation? = nil
      ) {
        self.ciImage = ciImage
        self.orientation = orientation
      }
    #endif

    #if canImport(CoreVideo)
      /// Creates image attachment content from a pixel buffer.
      internal init(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation? = nil
      ) {
        unsafe self.pixelBuffer = pixelBuffer
        self.orientation = orientation
      }
    #endif

    /// Returns whether two image attachment content values are equal.
    ///
    /// - Parameters:
    ///   - a: The first image attachment content to compare.
    ///   - b: The second image attachment content to compare.
    /// - Returns: `true` if the values are equal; otherwise, `false`.
    public static func == (a: ImageAttachmentContent, b: ImageAttachmentContent) -> Bool {
      if a.url != b.url {
        return false
      }
      if a.orientation != b.orientation {
        return false
      }
      #if canImport(CoreGraphics)
        if a.cgImage != b.cgImage {
          return false
        }
      #endif
      #if canImport(CoreImage)
        if a.ciImage != b.ciImage {
          return false
        }
      #endif
      #if canImport(CoreVideo)
        if unsafe a.pixelBuffer != b.pixelBuffer {
          return false
        }
      #endif
      return true
    }

    /// Converts this content to a transcript image attachment.
    internal var transcriptAttachment: Transcript.ImageAttachment {
      #if canImport(CoreGraphics)
        if let cg = self.cgImage {
          return Transcript.ImageAttachment(cg, orientation: orientation)
        }
      #endif
      #if canImport(CoreImage)
        if let ci = self.ciImage {
          return Transcript.ImageAttachment(ci, orientation: orientation)
        }
      #endif
      #if canImport(CoreVideo)
        if let pb = unsafe self.pixelBuffer {
          return Transcript.ImageAttachment(pb, orientation: orientation)
        }
      #endif
      if let u = self.url {
        return Transcript.ImageAttachment(imageURL: u, orientation: orientation)
      }
      guard let fallbackURL = URL(string: "about:blank") else {
        fatalError("about:blank URL is invalid")
      }
      return Transcript.ImageAttachment(imageURL: fallbackURL, orientation: orientation)
    }
  }

  extension Attachment where Content == ImageAttachmentContent {
    #if canImport(CoreGraphics)
      /// Creates an image attachment from a Core Graphics image.
      ///
      /// - Parameters:
      ///   - cgImage: The Core Graphics image to attach.
      ///   - orientation: The display orientation of the image.
      public init(_ cgImage: CGImage, orientation: CGImagePropertyOrientation? = nil) {
        self.init(
          content: ImageAttachmentContent(
            cgImage: cgImage,
            orientation: orientation
          )
        )
      }
    #endif

    #if canImport(CoreImage)
      /// Creates an image attachment from a Core Image image.
      ///
      /// - Parameters:
      ///   - ciImage: The Core Image image to attach.
      ///   - orientation: The display orientation of the image.
      public init(_ ciImage: CIImage, orientation: CGImagePropertyOrientation? = nil) {
        self.init(
          content: ImageAttachmentContent(
            ciImage: ciImage,
            orientation: orientation
          )
        )
      }
    #endif

    #if canImport(CoreVideo)
      /// Creates an image attachment from a Core Video pixel buffer.
      ///
      /// - Parameters:
      ///   - pixelBuffer: The Core Video pixel buffer to attach.
      ///   - orientation: The display orientation of the image.
      public init(_ pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation? = nil) {
        self.init(
          content: ImageAttachmentContent(
            pixelBuffer: pixelBuffer,
            orientation: orientation
          )
        )
      }
    #endif

    /// Creates an image attachment from an image file or network URL.
    ///
    /// - Parameters:
    ///   - imageURL: The URL of the image.
    ///   - orientation: The display orientation of the image.
    public init(imageURL: URL, orientation: CGImagePropertyOrientation? = nil) {
      self.init(
        content: ImageAttachmentContent(
          url: imageURL,
          orientation: orientation
        )
      )
    }
  }
#endif  // compiler(>=6.4)
