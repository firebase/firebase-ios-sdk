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
import FirebaseInstallations

let sessionIDUserDefaultsKey = "com.firebase.sessions.sessionID"
let lastSessionIDUserDefaultsKey = "com.firebase.sessions.lastSessionID"

protocol IdentifierProvider {
  var installationID: String {
    get
  }

  var sessionID: String {
    get
  }

  var lastSessionID: String {
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
  private let installationIDProvider: InstallationIDProvider

  private var uuid: UUID

  init(installationIDProvider: InstallationIDProvider) {
    self.installationIDProvider = installationIDProvider
    uuid = UUID()
  }

  public func generateNewSessionID() {
    uuid = UUID()

    let lastStoredSessionID = UserDefaults.standard.string(forKey: sessionIDUserDefaultsKey) ?? ""
    UserDefaults.standard.set(lastStoredSessionID, forKey: lastSessionIDUserDefaultsKey)

    let newSessionID = uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    UserDefaults.standard.set(newSessionID, forKey: sessionIDUserDefaultsKey)
  }

  // This method must be run on a background thread due to how Firebase Installations
  // handles threading.
  public var installationID: String {
    if Thread.isMainThread {
      Logger
        .logError(
          "Error: Identifiers.installationID getter must be called on a background thread. Using an empty ID"
        )
      return ""
    }

    var localInstallationID = ""

    let semaphore = DispatchSemaphore(value: 0)

    installationIDProvider.provideInstallationID { fiid, error in
      if error != nil {
        Logger
          .logError(
            "Error getting Firebase Installation ID: \(error.debugDescription). Using an empty ID"
          )
      }
      localInstallationID = fiid ?? ""
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

  public var sessionID: String {
    return UserDefaults.standard.string(forKey: sessionIDUserDefaultsKey) ?? ""
  }

  public var lastSessionID: String {
    return UserDefaults.standard.string(forKey: lastSessionIDUserDefaultsKey) ?? ""
  }
}
