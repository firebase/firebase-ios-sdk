// Copyright 2022 Google LLC
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

import FirebaseStorageInternal

/** Contains the prefixes and items returned by a `StorageReference.list()` call. */
@objc(FIRStorageListResult) open class StorageListResult: NSObject {
  /**
   * The prefixes (folders) returned by a `list()` operation.
   *
   * - Returns: A list of prefixes (folders).
   */
  @objc public let prefixes: [StorageReference]

  /**
   * The objects (files) returned by a `list()` operation.
   *
   * - Returns: A page token if more results are available.
   */
  @objc public let items: [StorageReference]

  /**
   * Returns a token that can be used to resume a previous `list()` operation. `nil`
   * indicates that there are no more results.
   *
   * - Returns: A page token if more results are available.
   */
  @objc public let pageToken: String?

  // MARK: - NSObject overrides

  @objc override open func copy() -> Any {
    return StorageListResult(impl.copy() as! FIRIMPLStorageListResult)
  }

  // MARK: - Internal APIs

  internal let impl: FIRIMPLStorageListResult

  internal init(_ impl: FIRIMPLStorageListResult) {
    self.impl = impl
    prefixes = impl.prefixes.map { StorageReference($0) }
    items = impl.items.map { StorageReference($0) }
    pageToken = impl.pageToken
  }
}
