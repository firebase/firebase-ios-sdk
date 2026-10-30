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

#if canImport(Darwin)
  private import os.lock

  /// A value protected by a mutual-exclusion lock, backed by `os_unfair_lock`.
  ///
  /// Mirrors the `withLock(_:)` API of `Synchronization.Mutex`, which requires macOS 15, iOS 18,
  /// tvOS 18, watchOS 11, or visionOS 2 on Apple platforms. The lock is heap-allocated because
  /// `os_unfair_lock` must have a stable address, which a stored property doesn't guarantee.
  package final class LockedValue<Value>: @unchecked Sendable {
    private let lockPointer: UnsafeMutablePointer<os_unfair_lock>
    private var value: Value

    /// Creates a lock protecting the given initial value.
    ///
    /// - Parameter value: The initial value to protect.
    package init(_ value: consuming sending Value) {
      lockPointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
      lockPointer.initialize(to: os_unfair_lock())
      self.value = value
    }

    deinit {
      lockPointer.deinitialize(count: 1)
      lockPointer.deallocate()
    }

    /// Calls the given closure while holding the lock, granting exclusive access to the value.
    ///
    /// - Parameter body: A closure that receives the protected value as an `inout` argument.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by `body`, if any.
    package func withLock<Result, E: Error>(
      _ body: (inout sending Value) throws(E) -> sending Result
    ) throws(E) -> sending Result {
      os_unfair_lock_lock(lockPointer)
      defer { os_unfair_lock_unlock(lockPointer) }
      return try body(&value)
    }
  }
#else
  // Imported without an access-level modifier because the `package` typealias exposes `Mutex`.
  import Synchronization

  /// A value protected by a mutual-exclusion lock; `Mutex` has no availability limits off Darwin.
  package typealias LockedValue<Value> = Mutex<Value>
#endif
