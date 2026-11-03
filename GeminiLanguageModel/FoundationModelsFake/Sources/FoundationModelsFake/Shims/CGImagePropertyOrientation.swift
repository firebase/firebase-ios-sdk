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
  #if !canImport(ImageIO)
    /// An orientation for displaying image data on platforms without ImageIO.
    public enum CGImagePropertyOrientation: UInt32, Sendable, Hashable {
      /// The default orientation where the image is not rotated or mirrored.
      case up = 1

      /// An orientation where the image is mirrored horizontally.
      case upMirrored = 2

      /// An orientation where the image is rotated 180 degrees.
      case down = 3

      /// An orientation where the image is mirrored vertically.
      case downMirrored = 4

      /// An orientation where the image is rotated 90 degrees counter-clockwise and mirrored.
      case leftMirrored = 5

      /// An orientation where the image is rotated 90 degrees clockwise.
      case right = 6

      /// An orientation where the image is rotated 90 degrees clockwise and mirrored.
      case rightMirrored = 7

      /// An orientation where the image is rotated 90 degrees counter-clockwise.
      case left = 8
    }
  #endif
#endif  // compiler(>=6.4)
