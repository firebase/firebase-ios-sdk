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
public struct ImagenInlineDataImage {
  public let mimeType: String
  public let data: Data

  init(mimeType: String, bytesBase64Encoded: String) {
    self.mimeType = mimeType
    guard let data = Data(base64Encoded: bytesBase64Encoded) else {
      // TODO(#14221): Add error handling for invalid base64 bytes.
      fatalError("Creating a `Data` from `bytesBase64Encoded` failed.")
    }
    self.data = data
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenInlineDataImage: ImagenImageRepresentable {
  public var _imagenImage: _ImagenImage {
    _ImagenImage(
      mimeType: mimeType,
      bytesBase64Encoded: data.base64EncodedString(),
      gcsURI: nil
    )
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenInlineDataImage: Equatable {}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenInlineDataImage: Decodable {
  enum CodingKeys: CodingKey {
    case mimeType
    case bytesBase64Encoded
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let mimeType = try container.decode(String.self, forKey: .mimeType)
    let bytesBase64Encoded = try container.decode(String.self, forKey: .bytesBase64Encoded)
    self.init(mimeType: mimeType, bytesBase64Encoded: bytesBase64Encoded)
  }
}
