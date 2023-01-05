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

@_implementationOnly import FirebaseInstallations

protocol IdentifierProvider {
  var sessionID: String {
    get
  }

  var previousSessionID: String? {
    get
  }
}

///
/// Identifiers is responsible for:
///   1) Getting the Installation ID from Installations
///   2) Generating the Session ID
///   3) Persisting and reading the Session ID from the last session
///   (Maybe) 4) Persisting, reading, and incrementing an increasing index
///
class Identifiers: IdentifierProvider {
  private var _sessionID: String?
  private var _previousSessionID: String?

  // Generates a new Session ID. If there was already a generated Session ID
  // from the last session during the app's lifecycle, it will also set the last Session ID
  func generateNewSessionID() {
    _previousSessionID = _sessionID
    _sessionID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }

  var sessionID: String {
    guard let _sessionID = _sessionID else {
      Logger.logError("Error: Sessions SDK did not generate a Session ID")
      return ""
    }
    return _sessionID
  }

  var previousSessionID: String? {
    return _previousSessionID
  }
}
