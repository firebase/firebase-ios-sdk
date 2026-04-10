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
#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)

/// A protocol describing any data that could be serialized to model-interpretable input data,
/// where the serialization process cannot fail with an error.
public protocol PartsRepresentable {
  var partsValue: [any Part] { get }
}

/// Enables a ``Part`` to be used as a ``PartsRepresentable``.
public extension Part {
  var partsValue: [any Part] {
    return [self]
  }
}

/// Enable an `Array` of ``PartsRepresentable`` values to be passed in as a single
/// ``PartsRepresentable``.
// swiftformat:disable:next typeSugar
extension Array<PartsRepresentable>: PartsRepresentable {
  // Note: this is written as Array<T> instead of [T] because
  // devsite doesn't like it when a toc title begins with [].
  public var partsValue: [any Part] {
    return flatMap { $0.partsValue }
  }
}

/// Enables a `String` to be passed in as ``PartsRepresentable``.
extension String: PartsRepresentable {
  public var partsValue: [any Part] {
    return [TextPart(self)]
  }
}

#if compiler(>=6.2.3) && canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension PartsRepresentable {
    func toFoundationModelsPrompt() throws -> FoundationModels.Prompt {
      return try partsValue.toFoundationModelsPrompt()
    }
  }
#endif // compiler(>=6.2.3) && canImport(FoundationModels)
