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
public struct ImagenGenerationResponse<T> {
  public let images: [T]
  public let filteredReason: String?
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenGenerationResponse: Decodable where T: Decodable {
  enum CodingKeys: CodingKey {
    case predictions
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    guard container.contains(.predictions) else {
      images = []
      filteredReason = nil
      // TODO(#14221): Log warning if no predictions.
      return
    }
    var predictionsContainer = try container.nestedUnkeyedContainer(forKey: .predictions)

    var images = [T]()
    var filteredReasons = [String]()
    while !predictionsContainer.isAtEnd {
      if let image = try? predictionsContainer.decode(T.self) {
        images.append(image)
      } else if let filteredReason = try? predictionsContainer.decode(RAIFilteredReason.self) {
        filteredReasons.append(filteredReason.raiFilteredReason)
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
    filteredReason = filteredReasons.first
    // TODO(#14221): Log if more than one RAI Filtered Reason; unexpected behaviour.
  }
}
