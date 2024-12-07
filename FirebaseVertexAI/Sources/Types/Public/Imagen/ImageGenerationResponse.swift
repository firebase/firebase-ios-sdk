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

import Foundation

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ImageGenerationResponse<ImageType: ImagenImageRepresentable> {
  public let images: [ImageType]
  public let raiFilteredReason: String?
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImageGenerationResponse: Decodable where ImageType: Decodable {
  enum CodingKeys: CodingKey {
    case predictions
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    guard container.contains(.predictions) else {
      images = []
      raiFilteredReason = nil
      // TODO(#14221): Log warning if no predictions.
      return
    }
    var predictionsContainer = try container.nestedUnkeyedContainer(forKey: .predictions)

    var images = [ImageType]()
    var raiFilteredReasons = [String]()
    while !predictionsContainer.isAtEnd {
      if let image = try? predictionsContainer.decode(ImageType.self) {
        images.append(image)
      } else if let filterReason = try? predictionsContainer.decode(RAIFilteredReason.self) {
        raiFilteredReasons.append(filterReason.raiFilteredReason)
      } else if let _ = try? predictionsContainer.decode(JSONObject.self) {
        // TODO(#14221): Log or throw unsupported prediction type
      } else {
        // This should never be thrown since JSONObject accepts any valid JSON.
        throw DecodingError.dataCorruptedError(
          in: predictionsContainer,
          debugDescription: "Failed to decode Prediction."
        )
      }
    }

    self.images = images
    raiFilteredReason = raiFilteredReasons.first
    // TODO(#14221): Log if more than one RAI Filtered Reason; unexpected behaviour.
  }
}
