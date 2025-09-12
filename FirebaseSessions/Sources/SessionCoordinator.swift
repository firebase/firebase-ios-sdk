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

protocol SessionCoordinatorProtocol: Sendable {
  func attemptLoggingSessionStart(event: SessionStartEvent,
                                  callback: @escaping @Sendable (Result<Void,
                                    FirebaseSessionsError>) -> Void)
}

///
/// SessionCoordinator is responsible for coordinating the systems in this SDK
/// involved with sending a Session Start event.
///
final class SessionCoordinator: SessionCoordinatorProtocol {
  let installations: InstallationsProtocol

  let fireLogger: EventGDTLoggerProtocol

  init(installations: InstallationsProtocol,
       fireLogger: EventGDTLoggerProtocol) {
    self.installations = installations
    self.fireLogger = fireLogger
  }

  /// Begins the process of logging a SessionStartEvent to FireLog after
  /// it has been approved for sending
  func attemptLoggingSessionStart(event: SessionStartEvent,
                                  callback: @escaping @Sendable (Result<
                                    Void,
                                    FirebaseSessionsError
                                  >)
                                    -> Void) {
    /// Order of execution
    /// 1. Fetch the installations Id. Regardless of success, move to step 2
    /// 2. Log the event. If successful, all is good. Else, log the message with error.
    /// 3. If there was a FireLog error, expose it to the callback. Otherwise expose the FIID
    /// error if it exists. Otherwise, success.
    fillInFIID(event: event) { fiidResult in
      self.fireLogger.logEvent(event: event) { logResult in
        switch logResult {
        case .success():
          Logger.logDebug("Successfully logged Session Start event to GoogleDataTransport")

          switch fiidResult {
          case .success(()):
            callback(.success(()))
          case let .failure(error):
            callback(.failure(error))
          }
        case let .failure(error):
          callback(.failure(FirebaseSessionsError.DataTransportError(error)))
        }
      }
    }
  }

  private func fillInFIID(event: SessionStartEvent,
                          callback: @escaping (Result<Void, FirebaseSessionsError>)
                            -> Void) {
    installations.installationID { result in
      switch result {
      case let .success(installationsInfo):
        event.setInstallationID(installationId: installationsInfo.0)
        event.setAuthenticationToken(authenticationToken: installationsInfo.1)
        callback(.success(()))
      case let .failure(error):
        event.setInstallationID(installationId: "")
        event.setAuthenticationToken(authenticationToken: "")
        callback(.failure(FirebaseSessionsError.SessionInstallationsError(error)))
      }
    }
  }
}
