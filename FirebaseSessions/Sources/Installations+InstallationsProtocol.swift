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
internal import FirebaseCoreInternal

protocol InstallationsProtocol: Sendable {
  var installationsWaitTimeInSecond: Int { get }

  /// Override Installation function for testing
  func authToken(completion: @escaping @Sendable (InstallationsAuthTokenResult?, Error?) -> Void)

  /// Override Installation function for testing
  func installationID(completion: @escaping @Sendable (String?, Error?) -> Void)

  /// Return a tuple: (installationID, authenticationToken) for success result
  func installationID(completion: @escaping (Result<(String, String), Error>) -> Void)
}

extension InstallationsProtocol {
  var installationsWaitTimeInSecond: Int {
    return 10
  }

  // TODO(ncooke3): Convert o async await ahead of Firebase 12.

  func installationID(completion: @escaping (Result<(String, String), Error>) -> Void) {
    let authTokenComplete = UnfairLock<String>("")
    let installationComplete = UnfairLock<String?>(nil)
    let errorComplete = UnfairLock<Error?>(nil)

    let workingGroup = DispatchGroup()

    workingGroup.enter()
    authToken { (authTokenResult: InstallationsAuthTokenResult?, error: Error?) in
      authTokenComplete.withLock { $0 = authTokenResult?.authToken ?? "" }
      workingGroup.leave()
    }

    workingGroup.enter()
    installationID { (installationID: String?, error: Error?) in
      if let installationID {
        installationComplete.withLock { $0 = installationID }
      } else if let error {
        errorComplete.withLock { $0 = error }
      }
      workingGroup.leave()
    }

    // adding timeout for 10 seconds
    let result = workingGroup
      .wait(timeout: .now() + DispatchTimeInterval.seconds(installationsWaitTimeInSecond))

    switch result {
    case .timedOut:
      completion(.failure(FirebaseSessionsError.SessionInstallationsTimeOutError))
      return
    default:
      if let installationComplete = installationComplete.value() {
        completion(.success((installationComplete, authTokenComplete.value())))
      } else if let errorComplete = errorComplete.value() {
        completion(.failure(errorComplete))
      }
    }
  }
}

extension Installations: InstallationsProtocol {}
