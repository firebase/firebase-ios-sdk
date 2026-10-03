// Copyright 2025 Google LLC
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
#if canImport(Darwin)
  private import os.lock
#else
  private import Synchronization
#endif

#if canImport(Darwin)
  /// A reference wrapper around `os_unfair_lock`. Replace this class with
  /// `OSAllocatedUnfairLock` once we support only iOS 16+. For an explanation
  /// on why this is necessary, see the docs:
  /// https://developer.apple.com/documentation/os/osallocatedunfairlock
  public final class UnfairLock<Value>: @unchecked Sendable {
    private let lockPointer: UnsafeMutablePointer<os_unfair_lock>
    private var _value: Value

    public init(_ value: consuming sending Value) {
      lockPointer = UnsafeMutablePointer<os_unfair_lock>
        .allocate(capacity: 1)
      lockPointer.initialize(to: os_unfair_lock())
      _value = value
    }

    deinit {
      lockPointer.deallocate()
    }

    #if FIREBASE_PORTABLE
      // Enforce `Value: Sendable` on Darwin portable builds to match `Mutex` on Linux.
      public func value() -> Value where Value: Sendable {
        lock()
        defer { unlock() }
        return _value
      }
    #else
      public func value() -> Value {
        lock()
        defer { unlock() }
        return _value
      }
    #endif

    @discardableResult
    public borrowing func withLock<Result>(_ body: (inout sending Value) throws
      -> sending Result) rethrows -> sending Result {
      lock()
      defer { unlock() }
      return try body(&_value)
    }

    @discardableResult
    public borrowing func withLock<Result>(_ body: (inout sending Value) -> sending Result)
      -> sending Result {
      lock()
      defer { unlock() }
      return body(&_value)
    }

    private func lock() {
      os_unfair_lock_lock(lockPointer)
    }

    private func unlock() {
      os_unfair_lock_unlock(lockPointer)
    }
  }
#else // canImport(Darwin)
  /// A reference wrapper around `Synchronization.Mutex` for non-Darwin platforms.
  public final class UnfairLock<Value>: Sendable {
    private let mutex: Mutex<Value>

    /// Creates a lock protecting the given initial value.
    ///
    /// - Parameter value: The initial value protected by the lock.
    public init(_ value: consuming sending Value) {
      mutex = Mutex(value)
    }

    /// Returns a copy of the protected value.
    ///
    /// - Returns: The current value protected by the lock.
    public func value() -> Value where Value: Sendable {
      mutex.withLock { $0 }
    }

    /// Calls the given throwing closure while holding the lock.
    ///
    /// - Parameter body: A closure that mutates the protected value.
    /// - Returns: The value returned by `body`.
    @discardableResult
    public borrowing func withLock<Result>(_ body: (inout sending Value) throws
      -> sending Result) rethrows -> sending Result {
      try mutex.withLock { value in
        try body(&value)
      }
    }

    /// Calls the given closure while holding the lock.
    ///
    /// - Parameter body: A closure that mutates the protected value.
    /// - Returns: The value returned by `body`.
    @discardableResult
    public borrowing func withLock<Result>(_ body: (inout sending Value) -> sending Result)
      -> sending Result {
      mutex.withLock { value in
        body(&value)
      }
    }
  }
#endif // canImport(Darwin)
