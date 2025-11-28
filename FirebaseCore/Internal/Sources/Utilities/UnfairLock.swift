
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

/// A thread-safe wrapper around a value.
public final class UnfairLock<Value>: @unchecked Sendable {
  private var lock: NSRecursiveLock = .init()
  private var _value: Value

  public init(_ value: consuming sending Value) {
    _value = value
  }

  public func value() -> Value {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  @discardableResult
  public borrowing func withLock<Result>(_ body: (inout sending Value) throws
    -> sending Result) rethrows -> sending Result {
    lock.lock()
    defer { lock.unlock() }
    return try body(&_value)
  }

  @discardableResult
  public borrowing func withLock<Result>(_ body: (inout sending Value) -> sending Result)
    -> sending Result {
    lock.lock()
    defer { lock.unlock() }
    return body(&_value)
  }
}
