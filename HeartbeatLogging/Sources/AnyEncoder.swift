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

/// A type that can encode an `Encodable` object into `Data`.
protocol AnyEncoder {
  func encode<T>(_ value: T) throws -> Data where T: Encodable
}

// MARK: - JSONDecoder + AnyEncoder

extension JSONEncoder: AnyEncoder {}

// MARK: - Encodable

extension Encodable {
  /// Returns the `Data` encoding of this value using the given encoder.
  /// - Parameter encoder: An encoder used to encode the value. Defaults to `JSONEncoder`.
  /// - Returns: The data encoding of the value.
  func encoded(using encoder: AnyEncoder = JSONEncoder()) throws -> Data {
    try encoder.encode(self)
  }
}
