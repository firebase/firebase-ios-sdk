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

/// A protocol for a persistent data storage container.
protocol AuthStorage: NSObjectProtocol {
  /// Creates a storage instance with the given identifier.
  /// - Parameter identifier: The storage's distinguishing identifer.
  static func storage(identifier: String) -> Self

  /// Retrieves the data for the given key from storage.
  /// - Parameter key: The key to use.
  /// - Returns: The data stored in the storage for the given key.
  /// - Throws: An error if the operation is not successful.
  func data(forKey key: String) throws -> Data?

  /// Sets the data for the given key from storage.
  /// - Parameters:
  ///   - data: The data to store.
  ///   - key: The key to use.
  /// - Throws: An error if the operation is not successful.
  func setData(_ data: Data, forKey key: String) throws

  /// Removes the data for the given key from storage.
  /// - Parameter key: The key to use.
  /// - Throws: An error if the operation is not successful.
  func removeData(forKey key: String) throws

  init(service: String)
}
