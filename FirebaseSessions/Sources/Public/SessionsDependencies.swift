//
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

private final class AtomicBox<T> {
  private var _value: T
  private let lock = NSLock()

  init(_ value: T) {
    _value = value
  }

  func value() -> T {
    lock.withLock {
      _value
    }
  }

  @discardableResult func withLock(_ body: (_ value: inout T) -> Void) -> T {
    lock.withLock {
      body(&_value)
      return _value
    }
  }
}

/// Sessions Dependencies determines when a dependent SDK is
/// installed in the app. The Sessions SDK uses this to figure
/// out which dependencies to wait for to getting the data
/// collection state.
///
/// This is important because the Sessions SDK starts up before
/// dependent SDKs
@objc(FIRSessionsDependencies)
public class SessionsDependencies: NSObject {
  #if compiler(>=6)
    private nonisolated(unsafe) static let _dependencies: AtomicBox<Set<SessionsSubscriberName>> =
      AtomicBox(
        Set()
      )
  #else
    private static let _dependencies: AtomicBox<Set<SessionsSubscriberName>> = AtomicBox(
      Set()
    )
  #endif

  static var dependencies: Set<SessionsSubscriberName> {
    _dependencies.value()
  }

  @objc public static func addDependency(name: SessionsSubscriberName) {
    _dependencies.withLock { dependencies in
      dependencies.insert(name)
    }
  }

  /// For testing only.
  static func removeAll() {
    _dependencies.withLock { dependencies in
      dependencies.removeAll()
    }
  }
}
