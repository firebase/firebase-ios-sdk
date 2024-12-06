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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
protocol DecodableImagenImage: ImagenImage, Decodable {
  init(mimeType: String, bytesBase64Encoded: String?, gcsURI: String?)
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
enum ImagenImageCodingKeys: String, CodingKey {
  case mimeType
  case bytesBase64Encoded
  case gcsURI = "gcsUri"
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension DecodableImagenImage {
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: ImagenImageCodingKeys.self)
    let mimeType = try container.decode(String.self, forKey: .mimeType)
    let bytesBase64Encoded = try container.decodeIfPresent(
      String.self,
      forKey: .bytesBase64Encoded
    )
    let gcsURI = try container.decodeIfPresent(String.self, forKey: .gcsURI)
    guard bytesBase64Encoded != nil || gcsURI != nil else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [ImagenImageCodingKeys.bytesBase64Encoded, ImagenImageCodingKeys.gcsURI],
          debugDescription: """
          Expected one of \(ImagenImageCodingKeys.bytesBase64Encoded.rawValue) or \
          \(ImagenImageCodingKeys.gcsURI.rawValue); both are nil.
          """
        )
      )
    }
    guard bytesBase64Encoded == nil || gcsURI == nil else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [ImagenImageCodingKeys.bytesBase64Encoded, ImagenImageCodingKeys.gcsURI],
          debugDescription: """
          Expected one of \(ImagenImageCodingKeys.bytesBase64Encoded.rawValue) or \
          \(ImagenImageCodingKeys.gcsURI.rawValue); both are specified.
          """
        )
      )
    }

    self.init(mimeType: mimeType, bytesBase64Encoded: bytesBase64Encoded, gcsURI: gcsURI)
  }
}
