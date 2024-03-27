// Copyright 2023 Google LLC
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

/// A protocol describing any data that could be serialized to model-interpretable input data,
/// where the serialization process might fail with an error.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public protocol ThrowingPartsRepresentable {
  func tryPartsValue() throws -> [ModelContent.Part]
}

/// A protocol describing any data that could be serialized to model-interpretable input data,
/// where the serialization process cannot fail with an error. For a failable conversion, see
/// ``ThrowingPartsRepresentable``
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public protocol PartsRepresentable: ThrowingPartsRepresentable {
  var partsValue: [ModelContent.Part] { get }
}

@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
public extension PartsRepresentable {
  func tryPartsValue() throws -> [ModelContent.Part] {
    return partsValue
  }
}

/// Enables a ``ModelContent.Part`` to be passed in as ``ThrowingPartsRepresentable``.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension ModelContent.Part: ThrowingPartsRepresentable {
  public typealias ErrorType = Never
  public func tryPartsValue() throws -> [ModelContent.Part] {
    return [self]
  }
}

/// Enable an `Array` of ``ThrowingPartsRepresentable`` values to be passed in as a single
/// ``ThrowingPartsRepresentable``.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension [ThrowingPartsRepresentable]: ThrowingPartsRepresentable {
  public func tryPartsValue() throws -> [ModelContent.Part] {
    return try compactMap { element in
      try element.tryPartsValue()
    }
    .flatMap { $0 }
  }
}

/// Enables a `String` to be passed in as ``ThrowingPartsRepresentable``.
@available(iOS 15.0, macOS 11.0, macCatalyst 15.0, *)
extension String: PartsRepresentable {
  public var partsValue: [ModelContent.Part] {
    return [.text(self)]
  }
}
