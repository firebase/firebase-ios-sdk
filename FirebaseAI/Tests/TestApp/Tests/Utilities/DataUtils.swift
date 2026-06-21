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

import AVFoundation
import SwiftUI

extension NSDataAsset {
  /// The preferred file extension for this asset, if any.
  ///
  /// This is set in the Asset catalog under the `File Type` field.
  var fileExtension: String? {
    UTType(typeIdentifier)?.preferredFilenameExtension
  }

  /// Extracts `.png` frames from a video at a rate of 1 FPS.
  ///
  /// - Returns:
  ///   An array of `Data` corresponding to individual images for each frame.
  func videoFrames() async throws -> [Data] {
    guard let fileExtension else {
      fatalError(
        "Failed to find file extension; ensure the \"File Type\" is set in the asset catalog."
      )
    }

    // we need a temp file so we can provide a URL to AVURLAsset
    let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString, isDirectory: false)
      .appendingPathExtension(fileExtension)

    try data.write(to: tempFileURL)

    defer {
      try? FileManager.default.removeItem(at: tempFileURL)
    }

    let asset = AVURLAsset(url: tempFileURL)
    let generator = AVAssetImageGenerator(asset: asset)

    let duration = try await asset.load(.duration).seconds
    return try stride(from: 0, to: duration, by: 1).map { seconds in
      let time = CMTime(seconds: seconds, preferredTimescale: 1)
      let cg = try generator.copyCGImage(at: time, actualTime: nil)

      let image = UIImage(cgImage: cg)
      guard let png = image.pngData() else {
        fatalError("Failed to encode image to png")
      }

      return png
    }
  }
}
