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
#if os(Linux)
  import FoundationNetworking
#endif

extension CodingUserInfoKey {
  static let configuration = CodingUserInfoKey(rawValue: "configuration")!
}

extension Decoder {
  func userInfoOrThrow<T>(_ name: CodingUserInfoKey) throws -> T {
    guard let value = userInfo[name] as? T else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: codingPath,
          debugDescription: "Missing userInfo entry for: \(name.rawValue)"
        )
      )
    }

    return value
  }
}

extension Encoder {
  func userInfoOrThrow<T>(_ name: CodingUserInfoKey) throws -> T {
    guard let value = userInfo[name] as? T else {
      throw DecodingError.dataCorrupted(
        .init(
          codingPath: codingPath,
          debugDescription: "Missing userInfo entry for: \(name.rawValue)"
        )
      )
    }

    return value
  }
}
