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
import os.lock

/// A reference wrapper around `os_unfair_lock`. Replace this class with
/// `OSAllocatedUnfairLock` once we support only iOS 16+. For an explanation
/// on why this is necessary, see the docs:
/// https://developer.apple.com/documentation/os/osallocatedunfairlock
public final class FIRAllocatedUnfairLock<State>: @unchecked Sendable {
  private var lockPointer: UnsafeMutablePointer<os_unfair_lock>
  private var state: State

  public init(initialState: sending State) {
    lockPointer = UnsafeMutablePointer<os_unfair_lock>
      .allocate(capacity: 1)
    lockPointer.initialize(to: os_unfair_lock())
    state = initialState
  }

  public convenience init() where State == Void {
    self.init(initialState: ())
  }

  public func lock() {
    os_unfair_lock_lock(lockPointer)
  }

  public func unlock() {
    os_unfair_lock_unlock(lockPointer)
  }

  public func value() -> State {
    lock()
    defer { unlock() }
    return state
  }

  @discardableResult
  public func withLock<R>(_ body: (inout State) throws -> R) rethrows -> R {
    let value: R
    lock()
    defer { unlock() }
    value = try body(&state)
    return value
  }

  @discardableResult
  public func withLock<R>(_ body: () throws -> R) rethrows -> R {
    let value: R
    lock()
    defer { unlock() }
    value = try body()
    return value
  }

  deinit {
    lockPointer.deallocate()
  }
}
