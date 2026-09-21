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

private import FirebaseCoreInternal
internal import FirebaseInstallations

struct SessionInfo: Sendable {
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
/// Generation happens on whichever thread initiates a session (typically the
/// main thread, via app lifecycle notifications), while `currentSession` is
/// read by subscribers on their own threads. The mutable state is therefore
/// guarded by a lock so this type can be safely `Sendable`.
///
final class SessionGenerator: Sendable {
  /// The generator's mutable state, only reachable while holding `state`.
  private struct State {
    var thisSession: SessionInfo?
    var firstSessionId: String = ""
    /// This will be incremented to 0 on the first generation.
    var sessionIndex: Int32 = -1
  }

  private let state = UnfairLock(State())
  private let collectEvents: Bool

  init(collectEvents: Bool) {
    self.collectEvents = collectEvents
  }

  // Generates a new Session ID. If there was already a generated Session ID
  // from the last session during the app's lifecycle, it will also set the last Session ID
  func generateNewSession() -> SessionInfo {
    // Generated outside the critical section: `UnfairLock` wraps
    // `os_unfair_lock`, which should be held only for the state
    // read-modify-write, never across allocations. The new ID is always
    // consumed, so there is no wasted work.
    let newSessionId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

    let collectEvents = self.collectEvents
    return state.withLock { state in
      // If firstSessionId is set, use it. Otherwise set it to the
      // first generated Session ID
      state.firstSessionId = state.firstSessionId.isEmpty ? newSessionId : state.firstSessionId

      state.sessionIndex += 1

      let newSession = SessionInfo(sessionId: newSessionId,
                                   firstSessionId: state.firstSessionId,
                                   dispatchEvents: collectEvents,
                                   sessionIndex: state.sessionIndex)
      state.thisSession = newSession
      return newSession
    }
  }

  var currentSession: SessionInfo? {
    state.withLock { $0.thisSession }
  }
}
