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
public struct ImagenFileDataImage {
  public let mimeType: String
  public let gcsURI: String

  init(mimeType: String, gcsURI: String) {
    self.mimeType = mimeType
    self.gcsURI = gcsURI
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenFileDataImage: ImagenImageRepresentable {
  public var _imagenImage: _ImagenImage {
    _ImagenImage(mimeType: mimeType, bytesBase64Encoded: nil, gcsURI: gcsURI)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenFileDataImage: Equatable {}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ImagenFileDataImage: Decodable {
  enum CodingKeys: String, CodingKey {
    case mimeType
    case gcsURI = "gcsUri"
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let mimeType = try container.decode(String.self, forKey: .mimeType)
    let gcsURI = try container.decode(String.self, forKey: .gcsURI)
    self.init(mimeType: mimeType, gcsURI: gcsURI)
  }
}
