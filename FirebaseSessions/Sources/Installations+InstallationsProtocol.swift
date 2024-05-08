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

protocol InstallationsProtocol {
  var installationsWaitTimeInSecond: Int { get }

  /// Override Installation function for testing
  func authToken(completion: @escaping (InstallationsAuthTokenResult?, Error?) -> Void)

  /// Override Installation function for testing
  func installationID(completion: @escaping (String?, Error?) -> Void)

  /// Return a tuple: (installationID, authenticationToken) for success result
  func installationID(completion: @escaping (Result<(String, String), Error>) -> Void)
}

extension InstallationsProtocol {
  var installationsWaitTimeInSecond: Int {
    return 10
  }

  func installationID(completion: @escaping (Result<(String, String), Error>) -> Void) {
    var authTokenComplete = ""
    var intallationComplete: String?
    var errorComplete: Error?

    let workingGroup = DispatchGroup()

    workingGroup.enter()
    authToken { (authTokenResult: InstallationsAuthTokenResult?, error: Error?) in
      authTokenComplete = authTokenResult?.authToken ?? ""
      workingGroup.leave()
    }

    workingGroup.enter()
    installationID { (installationID: String?, error: Error?) in
      if let installationID {
        intallationComplete = installationID
      } else if let error = error {
        errorComplete = error
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
      if let intallationComplete {
        completion(.success((intallationComplete, authTokenComplete)))
      } else if let errorComplete {
        completion(.failure(errorComplete))
      }
    }
  }
}

extension Installations: InstallationsProtocol {}
