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

/// A reference wrapper around `NSLock` for thread safety.
/// Used as a replacement for `UnfairLock` to ensure Linux compatibility.
public final class UnfairLock<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value

  public init(_ value: Value) {
    _value = value
  }

  public func value() -> Value {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  @discardableResult
  public func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
    lock.lock()
    defer { lock.unlock() }
    return try body(&_value)
  }

  @discardableResult
  public func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
    lock.lock()
    defer { lock.unlock() }
    return body(&_value)
  }
}
