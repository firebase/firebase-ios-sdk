// Copyright 2026 Google LLC
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

/// A type that can be initialized and populated fluently using a closure-based builder pattern.
package protocol Buildable {
  /// Initializes a new instance with default values.
  init()
}

extension Buildable {
  /// Initializes a new instance configured by `populator`.
  ///
  /// ```swift
  /// let request = GenerateContentRequest {
  ///   $0.contents = [...]
  /// }
  /// ```
  ///
  /// - Parameter populator: A closure that populates fields on the newly created instance.
  /// - Throws: Any error thrown by `populator`.
  @inlinable
  package init(_ populator: (inout Self) throws -> Void) rethrows {
    self.init()
    try populator(&self)
  }

  /// Initializes a new instance asynchronously configured by `populator`.
  ///
  /// ```swift
  /// let request = await GenerateContentRequest {
  ///   $0.contents = [await fetchUserContent()]
  /// }
  /// ```
  ///
  /// - Parameter populator: An asynchronous closure that populates fields on the newly created
  ///   instance.
  /// - Throws: Any error thrown by `populator`.
  @inlinable
  package init(_ populator: (inout Self) async throws -> Void) async rethrows {
    self.init()
    try await populator(&self)
  }

  /// Returns a copy of this instance modified by `populator`.
  ///
  /// ```swift
  /// let modified = baseConfig.with {
  ///   $0.temperature = 0.2
  /// }
  /// ```
  ///
  /// - Parameter populator: A closure that populates or updates fields on a copy of this instance.
  /// - Returns: The populated copy.
  /// - Throws: Any error thrown by `populator`.
  @inlinable
  package func with(_ populator: (inout Self) throws -> Void) rethrows -> Self {
    var copy = self
    try populator(&copy)
    return copy
  }

  /// Creates a new instance, executes `populator` to populate its fields, and returns the instance.
  ///
  /// ```swift
  /// let request = GenerateContentRequest.with {
  ///   $0.contents = [...]
  /// }
  /// ```
  ///
  /// - Parameter populator: A closure that populates fields on the newly created instance.
  /// - Returns: The populated instance.
  /// - Throws: Any error thrown by `populator`.
  @inlinable
  package static func with(_ populator: (inout Self) throws -> Void) rethrows -> Self {
    var instance = Self()
    try populator(&instance)
    return instance
  }
}
