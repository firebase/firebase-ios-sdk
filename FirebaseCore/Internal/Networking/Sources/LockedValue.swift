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

/// A value that's protected by a lock.
///
/// The networking code builds on Linux for development, where `os_unfair_lock` isn't available,
/// so it uses this `NSLock`-based type instead of `UnfairLock`. Under CocoaPods both types compile
/// into `FirebaseCoreInternal`, so their names must differ.
final class LockedValue<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var storage: Value

  /// Creates a lock that protects `value`.
  init(_ value: consuming sending Value) {
    storage = value
  }

  /// Returns a copy of the protected value.
  func value() -> Value {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }

  /// Calls `body` with exclusive access to the protected value.
  ///
  /// The lock isn't recursive: calling `withLock` on the same instance from `body` deadlocks.
  @discardableResult
  borrowing func withLock<Result>(_ body: (inout sending Value) throws -> sending Result) rethrows
    -> sending Result {
    lock.lock()
    defer { lock.unlock() }
    return try body(&storage)
  }

  /// Calls `body` with exclusive access to the protected value.
  ///
  /// The lock isn't recursive: calling `withLock` on the same instance from `body` deadlocks.
  @discardableResult
  borrowing func withLock<Result>(_ body: (inout sending Value) -> sending Result)
    -> sending Result {
    lock.lock()
    defer { lock.unlock() }
    return body(&storage)
  }
}
