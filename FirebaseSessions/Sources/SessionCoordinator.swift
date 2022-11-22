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

///
/// SessionCoordinator is responsible for coordinating the systems in this SDK
/// involved with sending a Session Start event.
///
class SessionCoordinator {
  let identifiers: IdentifierProvider
  let fireLogger: EventGDTLoggerProtocol
  let sampler: SessionSamplerProtocol

  init(identifiers: IdentifierProvider, fireLogger: EventGDTLoggerProtocol,
       sampler: SessionSamplerProtocol) {
    self.identifiers = identifiers
    self.fireLogger = fireLogger
    self.sampler = sampler
  }

  // Begins the process of logging a SessionStartEvent to FireLog, while taking into account Data Collection, Sampling, and fetching Settings
  func attemptLoggingSessionStart(event: SessionStartEvent,
                                  callback: @escaping (Result<Void, Error>) -> Void) {
    if sampler.shouldSendEventForSession(sessionId: identifiers.sessionID) {
      event.setInstallationID(identifiers: identifiers)

      fireLogger.logEvent(event: event) { result in
        switch result {
        case .success():
          Logger.logInfo("Successfully logged Session Start event to GoogleDataTransport")
          callback(.success(()))
        case let .failure(error):
          Logger
            .logError(
              "Error logging Session Start event to GoogleDataTransport: \(error)."
            )
          callback(.failure(error))
        }
      }
    } else {
      Logger
        .logInfo(
          "Session event dropped due to sampling."
        )
      callback(.failure(FirebaseSessionsError.SessionSampledError))
    }
  }
}
