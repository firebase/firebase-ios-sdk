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

internal import FirebaseInstallations

struct SessionInfo {
  let sessionId: String
  let firstSessionId: String
  let shouldDispatchEvents: Bool
  let sessionIndex: Int32

  init(sessionId: String, firstSessionId: String, dispatchEvents: Bool, sessionIndex: Int32) {
    self.sessionId = sessionId
    self.firstSessionId = firstSessionId
    shouldDispatchEvents = dispatchEvents
    self.sessionIndex = sessionIndex
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

  private var firstSessionId = ""
  private var sessionIndex: Int32
  private var collectEvents: Bool

  init(collectEvents: Bool) {
    // This will be incremented to 0 on the first generation
    sessionIndex = -1

    self.collectEvents = collectEvents
  }

  // Generates a new Session ID. If there was already a generated Session ID
  // from the last session during the app's lifecycle, it will also set the last Session ID
  func generateNewSession() -> SessionInfo {
    let newSessionId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

    // If firstSessionId is set, use it. Otherwise set it to the
    // first generated Session ID
    firstSessionId = firstSessionId.isEmpty ? newSessionId : firstSessionId

    sessionIndex += 1

    let newSession = SessionInfo(sessionId: newSessionId,
                                 firstSessionId: firstSessionId,
                                 dispatchEvents: collectEvents,
                                 sessionIndex: sessionIndex)
    thisSession = newSession
    return newSession
  }

  var currentSession: SessionInfo? {
    return thisSession
  }
}
