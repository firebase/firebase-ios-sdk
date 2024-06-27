// Copyright 2023 Google LLC
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

/// Protocol to manage keychain updates. Tests can do a fake implementation.

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
protocol AuthKeychainStorage {
  func get(query: [String: Any], result: inout AnyObject?) -> OSStatus
  func add(query: [String: Any]) -> OSStatus
  func update(query: [String: Any], attributes: [String: Any]) -> OSStatus
  @discardableResult func delete(query: [String: Any]) -> OSStatus
}
