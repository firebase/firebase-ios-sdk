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

import Foundation

/// Represents the placement of an image within a larger canvas.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public enum ImagenImagePlacement: Sendable {
  /// The image is placed at the top left corner of the canvas.
  case topLeft

  /// The image is placed at the top center of the canvas.
  case topCenter

  /// The image is placed at the top right corner of the canvas.
  case topRight

  /// The image is placed at the middle left of the canvas.
  case middleLeft

  /// The image is placed in the center of the canvas.
  case center

  /// The image is placed at the middle right of the canvas.
  case middleRight

  /// The image is placed at the bottom left corner of the canvas.
  case bottomLeft

  /// The image is placed at the bottom center of the canvas.
  case bottomCenter

  /// The image is placed at the bottom right corner of the canvas.
  case bottomRight

  /// The image is placed at a custom offset from the top left corner of the canvas.
  case custom(x: Int, y: Int)
}
