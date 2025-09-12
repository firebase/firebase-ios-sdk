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

import FirebaseAppCheckInterop
import Foundation

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
class AppCheckInteropFake: NSObject, AppCheckInterop {
  /// The placeholder token value returned when an error occurs
  static let placeholderTokenValue = "placeholder-token"

  var token: String
  var error: Error?

  private init(token: String, error: Error?) {
    self.token = token
    self.error = error
  }

  convenience init(token: String) {
    self.init(token: token, error: nil)
  }

  convenience init(error: Error) {
    self.init(token: AppCheckInteropFake.placeholderTokenValue, error: error)
  }

  func getToken(forcingRefresh: Bool) async -> any FIRAppCheckTokenResultInterop {
    return AppCheckTokenResultInteropFake(token: token, error: error)
  }

  func getLimitedUseToken() async -> any FIRAppCheckTokenResultInterop {
    return AppCheckTokenResultInteropFake(token: "limited_use_\(token)", error: error)
  }

  func tokenDidChangeNotificationName() -> String {
    fatalError("\(#function) not implemented.")
  }

  func notificationTokenKey() -> String {
    fatalError("\(#function) not implemented.")
  }

  func notificationAppNameKey() -> String {
    fatalError("\(#function) not implemented.")
  }

  private class AppCheckTokenResultInteropFake: NSObject, FIRAppCheckTokenResultInterop,
    @unchecked Sendable {
    let token: String
    let error: Error?

    init(token: String, error: Error?) {
      self.token = token
      self.error = error
    }
  }
}

struct AppCheckErrorFake: Error {}
