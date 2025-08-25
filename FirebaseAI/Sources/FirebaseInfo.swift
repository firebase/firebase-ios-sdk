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

// TODO: Remove `@preconcurrency` when possible.
@preconcurrency import FirebaseAppCheckInterop
@preconcurrency import FirebaseAuthInterop
@preconcurrency import FirebaseCore

/// Firebase data used by FirebaseAI
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct FirebaseInfo: Sendable {
  let appCheck: AppCheckInterop?
  let auth: AuthInterop?
  let projectID: String
  let apiKey: String
  let firebaseAppID: String
  let useLimitedUseAppCheckTokens: Bool
  let app: FirebaseApp

  init(appCheck: AppCheckInterop? = nil,
       auth: AuthInterop? = nil,
       projectID: String,
       apiKey: String,
       firebaseAppID: String,
       firebaseApp: FirebaseApp,
       useLimitedUseAppCheckTokens: Bool) {
    self.appCheck = appCheck
    self.auth = auth
    self.projectID = projectID
    self.apiKey = apiKey
    self.firebaseAppID = firebaseAppID
    self.useLimitedUseAppCheckTokens = useLimitedUseAppCheckTokens
    app = firebaseApp
  }
}
