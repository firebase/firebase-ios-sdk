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

struct SessionInfo {
  let sessionId: String
  let previousSessionId: String?
  let shouldDispatchEvents: Bool

  init(sessionId: String, previousSessionId: String?, dispatchEvents: Bool) {
    self.sessionId = sessionId
    self.previousSessionId = previousSessionId
    shouldDispatchEvents = dispatchEvents
  }
}

///
/// Generator is responsible for:
///   1) Generating the Session ID
///   2) Persisting and reading the Session ID from the last session
///   (Maybe) 3) Persisting, reading, and incrementing an increasing index
///
class SessionGenerator {
  private var thisSession: SessionInfo?
  private var settings: SettingsProtocol

  init(settings: SettingsProtocol) {
    self.settings = settings
  }

  // Generates a new Session ID. If there was already a generated Session ID
  // from the last session during the app's lifecycle, it will also set the last Session ID
  func generateNewSession() -> SessionInfo {
    let newSessionId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

    var collectEvents = true
    let randomValue = Double.random(in: 0 ... 1)

    if randomValue > settings.samplingRate {
      collectEvents = false
    }

    let newSession = SessionInfo(sessionId: newSessionId,
                                 previousSessionId: thisSession?.sessionId,
                                 dispatchEvents: collectEvents)
    thisSession = newSession
    return newSession
  }

  var currentSession: SessionInfo? {
    return thisSession
  }
}
