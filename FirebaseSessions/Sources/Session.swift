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

protocol SessionProtocol {
  var installationID: String {
    get
  }

  var sessionID: String {
    get
  }

  var previousSessionID: String? {
    get
  }
}

///
/// Session is responsible for:
///   1) Getting the Installation ID from Installations
///   2) Generating the Session ID
///   3) Persisting and reading the Session ID from the last session
///   (Maybe) 4) Persisting, reading, and incrementing an increasing index
///
class Session: SessionProtocol {
  private let installations: InstallationsProtocol

  private var _sessionID: String?
  private var _previousSessionID: String?

  init(installations: InstallationsProtocol) {
    self.installations = installations
  }

  // Generates a new Session ID. If there was already a generated Session ID
  // from the last session during the app's lifecycle, it will also set the last Session ID
  func generateNewSessionID() {
    _previousSessionID = _sessionID
    _sessionID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }

  // Fetches the Installation ID from Firebase Installation Service. This method must be run on a background thread due to how Firebase Installations
  // handles threading.
  var installationID: String {
    if Thread.isMainThread {
      Logger
        .logError(
          "Error: Session.installationID getter must be called on a background thread. Using an empty ID"
        )
      return ""
    }

    var localInstallationID = ""

    let semaphore = DispatchSemaphore(value: 0)

    installations.installationID { result in
      switch result {
      case let .success(fiid):
        localInstallationID = fiid
      case let .failure(error):
        Logger
          .logError(
            "Error getting Firebase Installation ID: \(error). Using an empty ID"
          )
      }

      semaphore.signal()
    }

    switch semaphore.wait(timeout: DispatchTime.now() + 1.0) {
    case .success:
      break
    case .timedOut:
      Logger.logError("Error: took too long to get the Firebase Installation ID. Using an empty ID")
    }

    return localInstallationID
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
