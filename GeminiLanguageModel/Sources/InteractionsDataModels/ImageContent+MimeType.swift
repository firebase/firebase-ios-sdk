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

extension ImageContent {
  /// The mime type of the image.
  package enum MimeType: Codable, Sendable, Equatable, Hashable {

    /// PNG image format
    case png

    /// JPEG image format
    case jpeg

    /// WebP image format
    case webp

    /// HEIC image format
    case heic

    /// HEIF image format
    case heif

    /// GIF image format
    case gif

    /// BMP image format
    case bmp

    /// TIFF image format
    case tiff

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension ImageContent.MimeType: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .png: "image/png"
    case .jpeg: "image/jpeg"
    case .webp: "image/webp"
    case .heic: "image/heic"
    case .heif: "image/heif"
    case .gif: "image/gif"
    case .bmp: "image/bmp"
    case .tiff: "image/tiff"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "image/png": self = .png
    case "image/jpeg": self = .jpeg
    case "image/webp": self = .webp
    case "image/heic": self = .heic
    case "image/heif": self = .heif
    case "image/gif": self = .gif
    case "image/bmp": self = .bmp
    case "image/tiff": self = .tiff
    default: self = .unrecognized(rawValue)
    }
  }
}
