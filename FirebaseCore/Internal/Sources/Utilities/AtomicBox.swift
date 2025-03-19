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

final class AtomicBox<T> {
  private var _value: T
  private let lock = NSLock()

  public init(_ value: T) {
    _value = value
  }

  public func value() -> T {
    lock.withLock {
      _value
    }
  }

  @discardableResult
  public func withLock(_ mutatingBody: (_ value: inout T) -> Void) -> T {
    lock.withLock {
      mutatingBody(&_value)
      return _value
    }
  }

  @discardableResult
  public func withLock<R>(_ mutatingBody: (_ value: inout T) throws -> R) rethrows -> R {
    try lock.withLock {
      try mutatingBody(&_value)
    }
  }
}
