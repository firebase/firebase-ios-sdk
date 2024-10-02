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

import FirebaseAppCheckInterop
import FirebaseCoreExtension

/// Defines configurations to be added to a request to Firebase Auth's backend.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthRequestConfiguration {
  /// The Firebase Auth API key used in the request.
  let apiKey: String

  /// The language code used in the request.
  var languageCode: String?

  /// The Firebase appID used in the request.
  let appID: String

  /// The `Auth` instance used in the request.
  weak var auth: Auth?

  /// The heartbeat logger used to add heartbeats to the corresponding request's header.
  var heartbeatLogger: FIRHeartbeatLoggerProtocol?

  /// The appCheck is used to generate a token.
  var appCheck: AppCheckInterop?

  /// The HTTP method used in the request.
  var httpMethod: String

  /// Additional framework marker that will be added as part of the header of every request.
  var additionalFrameworkMarker: String?

  /// If set, the local emulator host and port to point to instead of the remote backend.
  var emulatorHostAndPort: String?

  init(apiKey: String,
       appID: String,
       auth: Auth? = nil,
       heartbeatLogger: FIRHeartbeatLoggerProtocol? = nil,
       appCheck: AppCheckInterop? = nil) {
    self.apiKey = apiKey
    self.appID = appID
    self.auth = auth
    self.heartbeatLogger = heartbeatLogger
    self.appCheck = appCheck
    httpMethod = "POST"
  }
}
