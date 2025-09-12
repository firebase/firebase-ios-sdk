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
private import os.lock

/// A reference wrapper around `os_unfair_lock`. Replace this class with
/// `OSAllocatedUnfairLock` once we support only iOS 16+. For an explanation
/// on why this is necessary, see the docs:
/// https://developer.apple.com/documentation/os/osallocatedunfairlock
public final class UnfairLock<Value>: @unchecked Sendable {
  private var lockPointer: UnsafeMutablePointer<os_unfair_lock>
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

  public func value() -> Value {
    lock()
    defer { unlock() }
    return _value
  }

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
