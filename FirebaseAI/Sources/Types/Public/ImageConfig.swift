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

/// Configuration for controlling generated image properties such as aspect ratio and image size.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ImageConfig: Sendable {
  let aspectRatio: AspectRatio?
  let imageSize: ImageSize?

  /// Initializes an `ImageConfig` with the given aspect ratio and image size.
  ///
  /// - Parameters:
  ///   - aspectRatio: The aspect ratio for generated images.
  ///   - imageSize: The size for generated images.
  public init(aspectRatio: AspectRatio? = nil, imageSize: ImageSize? = nil) {
    self.aspectRatio = aspectRatio
    self.imageSize = imageSize
  }
}

/// An aspect ratio for generated images.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public extension ImageConfig {
  struct AspectRatio: Sendable {
    /// Square (1:1) aspect ratio.
    ///
    /// Common uses for this aspect ratio include social media posts.
    public static let square1x1 = AspectRatio(kind: .square1x1)

    /// Portrait widescreen (9:16) aspect ratio.
    ///
    /// This is the ``landscape16x9`` aspect ratio rotated 90 degrees. This a relatively new aspect
    /// ratio that has been popularized by short form video apps (for example, YouTube shorts). Use
    /// this for tall objects with strong vertical orientations such as buildings, trees,
    /// waterfalls, or other similar objects.
    public static let portrait9x16 = AspectRatio(kind: .portrait9x16)

    /// Widescreen (16:9) aspect ratio.
    ///
    /// This ratio has replaced ``landscape4x3`` as the most common aspect ratio for TVs, monitors,
    /// and mobile phone screens (landscape). Use this aspect ratio when you want to capture more of
    /// the background (for example, scenic landscapes).
    public static let landscape16x9 = AspectRatio(kind: .landscape16x9)

    /// Portrait full screen (3:4) aspect ratio.
    ///
    /// This is the ``landscape4x3`` aspect ratio rotated 90 degrees. This lets to capture more of
    /// the scene vertically compared to the ``square1x1`` aspect ratio.
    public static let portrait3x4 = AspectRatio(kind: .portrait3x4)

    /// Fullscreen (4:3) aspect ratio.
    ///
    /// This aspect ratio is commonly used in media or film. It is also the dimensions of most old
    /// (non-widescreen) TVs and medium format cameras. It captures more of the scene horizontally
    /// (compared to ``square1x1``), making it a preferred aspect ratio for photography.
    public static let landscape4x3 = AspectRatio(kind: .landscape4x3)

    let rawValue: String
  }

  /// The size of images to generate.
  struct ImageSize: Sendable {
    /// 512px (0.5K) image size.
    ///
    /// This corresponds to 512x512 pixel images in a ``ImageConfig/AspectRatio/square1x1`` aspect
    /// ratio. See the [documentation
    /// ](https://ai.google.dev/gemini-api/docs/image-generation#aspect_ratios_and_image_size)
    /// for specific sizes in other aspect ratios.
    public static let size512 = ImageSize(kind: .size512)

    /// 1K image size.
    ///
    /// This corresponds to 1024x1024 pixel images in a ``ImageConfig/AspectRatio/square1x1`` aspect
    /// ratio. See the [documentation
    /// ](https://ai.google.dev/gemini-api/docs/image-generation#aspect_ratios_and_image_size)
    /// for specific sizes in other aspect ratios.
    public static let size1K = ImageSize(kind: .size1K)

    /// 2K image size.
    ///
    /// This corresponds to 2048x2048 pixel images in a ``ImageConfig/AspectRatio/square1x1`` aspect
    /// ratio. See the [documentation
    /// ](https://ai.google.dev/gemini-api/docs/image-generation#aspect_ratios_and_image_size)
    /// for specific sizes in other aspect ratios.
    public static let size2K = ImageSize(kind: .size2K)

    /// 4K image size.
    ///
    /// This corresponds to 4096x4096 pixel images in a ``ImageConfig/AspectRatio/square1x1`` aspect
    /// ratio. See the [documentation
    /// ](https://ai.google.dev/gemini-api/docs/image-generation#aspect_ratios_and_image_size)
    /// for specific sizes in other aspect ratios.
    public static let size4K = ImageSize(kind: .size4K)

    let rawValue: String
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImageConfig.AspectRatio: ProtoEnum {
  enum Kind: String {
    case square1x1 = "1:1"
    case portrait9x16 = "9:16"
    case landscape16x9 = "16:9"
    case portrait3x4 = "3:4"
    case landscape4x3 = "4:3"
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImageConfig.ImageSize: ProtoEnum {
  enum Kind: String {
    case size512 = "512"
    case size1K = "1K"
    case size2K = "2K"
    case size4K = "4K"
  }
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImageConfig: Encodable {}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImageConfig.AspectRatio: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImageConfig.ImageSize: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
