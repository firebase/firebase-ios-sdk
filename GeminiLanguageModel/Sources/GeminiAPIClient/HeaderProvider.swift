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

/// A thread-safe, hashable wrapper around an asynchronous header provider closure.
///
/// Because closures cannot conform to `Equatable` or `Hashable`, each `HeaderProvider`
/// generates a unique identifier upon initialization. This allows it to be used in hashable
/// configuration types such as `Executor.Configuration`.
package struct HeaderProvider: Sendable {
  private let id = UUID()
  private let headerProvider: @Sendable () async throws -> [String: String]

  /// Creates a new header provider wrapping the specified async closure.
  ///
  /// - Parameter headerProvider: An async closure that supplies dynamic HTTP headers.
  package init(_ headerProvider: @Sendable @escaping () async throws -> [String: String]) {
    self.headerProvider = headerProvider
  }

  /// Invokes the underlying closure to produce HTTP headers.
  ///
  /// - Returns: A dictionary of HTTP header fields and values.
  /// - Throws: Any error thrown by the underlying header provider closure.
  package func callAsFunction() async throws -> [String: String] {
    try await headerProvider()
  }
}

// MARK: - Equatable

extension HeaderProvider: Equatable {
  /// Indicates whether two header providers are identical instances.
  ///
  /// - Parameters:
  ///   - lhs: A header provider to compare.
  ///   - rhs: Another header provider to compare.
  /// - Returns: `true` if both instances share the same identifier, otherwise `false`.
  package static func == (lhs: HeaderProvider, rhs: HeaderProvider) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - Hashable

extension HeaderProvider: Hashable {
  /// Hashes the essential components of this value into the given hasher.
  ///
  /// - Parameter hasher: The hasher to use when combining the components of this instance.
  package func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
