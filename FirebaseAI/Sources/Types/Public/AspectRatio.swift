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

/// An aspect ratio for generated images.
public struct AspectRatio: Sendable {
  /// The raw string value of the aspect ratio.
  let rawValue: String

  /// Creates a new aspect ratio with a raw string value.
  private init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Square (1:1) aspect ratio.
  public static let square1x1 = AspectRatio(rawValue: "1:1")

  /// Portrait (2:3) aspect ratio.
  public static let portrait2x3 = AspectRatio(rawValue: "2:3")

  /// Landscape (3:2) aspect ratio.
  public static let landscape3x2 = AspectRatio(rawValue: "3:2")

  /// Portrait (3:4) aspect ratio.
  public static let portrait3x4 = AspectRatio(rawValue: "3:4")

  /// Landscape (4:3) aspect ratio.
  public static let landscape4x3 = AspectRatio(rawValue: "4:3")

  /// Portrait (4:5) aspect ratio.
  public static let portrait4x5 = AspectRatio(rawValue: "4:5")

  /// Landscape (5:4) aspect ratio.
  public static let landscape5x4 = AspectRatio(rawValue: "5:4")

  /// Portrait (9:16) aspect ratio.
  public static let portrait9x16 = AspectRatio(rawValue: "9:16")

  /// Landscape (16:9) aspect ratio.
  public static let landscape16x9 = AspectRatio(rawValue: "16:9")

  /// Landscape (21:9) aspect ratio.
  public static let landscape21x9 = AspectRatio(rawValue: "21:9")
}

// MARK: - Codable Conformances

extension AspectRatio: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
