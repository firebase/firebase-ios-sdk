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

/// A synchronization primitive that protects a value with an `NSLock`, mirroring the API of
/// `Synchronization.Mutex`.
///
/// Swift classes are listed in the binary's Objective-C class list regardless of their
/// `@available` annotations, so the Objective-C runtime can realize them on OS versions that
/// predate `Mutex` (for example, when an app or library calls `objc_copyClassList`). If a stored
/// `Mutex` property requires runtime layout, realizing the class calls the weakly linked `Mutex`
/// metadata accessor, which is `NULL` on those OS versions and crashes the app.
///
/// Unlike `Mutex`, which is a noncopyable struct that stores its value inline, this type is a class,
/// so properties of this type have a fixed size that doesn't depend on `Value`.
final class LockedValue<Value: ~Copyable>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  /// Initializes a value of this lock with the given initial state.
  ///
  /// - Parameter initialValue: The initial value to give to the lock.
  init(_ initialValue: consuming sending Value) {
    self.value = initialValue
  }

  /// Calls the given closure after acquiring the lock and then releases ownership.
  ///
  /// - Parameter body: A closure with a parameter of `Value` that has exclusive access to the value
  ///   being stored within this lock.
  /// - Returns: The return value, if any, of the `body` closure parameter.
  /// - Throws: The error, if any, thrown by the `body` closure parameter.
  borrowing func withLock<Result: ~Copyable, E: Error>(
    _ body: (inout sending Value) throws(E) -> sending Result
  ) throws(E) -> sending Result {
    lock.lock()
    defer { lock.unlock() }
    return try body(&value)
  }
}
