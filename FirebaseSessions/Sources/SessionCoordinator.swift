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

protocol SessionCoordinatorProtocol {
  func attemptLoggingSessionStart(event: SessionStartEvent,
                                  callback: @escaping (Result<Void, FirebaseSessionsError>) -> Void)
}

///
/// SessionCoordinator is responsible for coordinating the systems in this SDK
/// involved with sending a Session Start event.
///
class SessionCoordinator: SessionCoordinatorProtocol {
  let installations: InstallationsProtocol
  let fireLogger: EventGDTLoggerProtocol

  init(installations: InstallationsProtocol,
       fireLogger: EventGDTLoggerProtocol) {
    self.installations = installations
    self.fireLogger = fireLogger
  }

  // Begins the process of logging a SessionStartEvent to FireLog, while taking into account Data Collection, Sampling, and fetching Settings
  func attemptLoggingSessionStart(event: SessionStartEvent,
                                  callback: @escaping (Result<Void, FirebaseSessionsError>)
                                    -> Void) {
    /// Order of execution
    /// 1. Check if the session can be sent. If yes, move to 2. Else, drop the event.
    /// 2. Fetch the installations Id. If successful, move to 3. Else, drop sending the event.
    /// 3. Log the event. If successful, all is good. Else, log the message with error.
    installations.installationID { result in
      switch result {
      case let .success(fiid):
        event.setInstallationID(installationId: fiid)
        self.fireLogger.logEvent(event: event) { logResult in
          switch logResult {
          case .success():
            callback(.success(()))
          case let .failure(error):
            callback(.failure(FirebaseSessionsError.DataTransportError(error)))
          }
        }
      case let .failure(error):
        callback(.failure(FirebaseSessionsError.SessionInstallationsError(error)))
      }
    }
  }
}
