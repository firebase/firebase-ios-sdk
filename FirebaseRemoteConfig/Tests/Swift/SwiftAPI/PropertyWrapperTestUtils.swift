/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@testable import FirebaseRemoteConfig

/// Returns the value that `@RemoteConfigProperty(key: key, fallback: fallback) var value: T`
/// exposes.
///
/// `RemoteConfigProperty` keeps its `RemoteConfigValueObservable` in a `@StateObject`, and SwiftUI
/// only supports reading a `@StateObject` from a view that it has installed. Reading the wrapped
/// value anywhere else makes SwiftUI create a new observable for each read and report a runtime
/// warning, which XCTest detects as a runtime issue. Create the observable the same way
/// `RemoteConfigProperty` does and read its value instead.
func remoteConfigPropertyValue<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
  RemoteConfigValueObservable(key: key, fallbackValue: fallback).configValue
}
