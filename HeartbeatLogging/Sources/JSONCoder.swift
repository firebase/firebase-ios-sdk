// Copyright 2021 Google LLC
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

protocol Encoding {
  func encode<T>(_ value: T) throws -> Data where T: Encodable
}

protocol Decoding {
  func decode<T>(_ type: T.Type,
                 from data: Data) throws -> T where T: Decodable
}

typealias Coder = Encoding & Decoding

class JSONCoder: Coder {
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(encoder: JSONEncoder = .init(),
       decoder: JSONDecoder = .init()) {
    self.encoder = encoder
    self.decoder = decoder
  }

  func encode<T>(_ value: T) throws -> Data where T: Encodable {
    try encoder.encode(value)
  }

  func decode<T>(_ type: T.Type,
                 from data: Data) throws -> T where T: Decodable {
    try decoder.decode(type, from: data)
  }
}
