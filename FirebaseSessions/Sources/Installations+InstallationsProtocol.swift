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
  /// Override Installation function for testing
  func authToken(completion: @escaping (InstallationsAuthTokenResult?, Error?) -> Void)

  /// Override Installation function for testing
  func installationID(completion: @escaping (String?, Error?) -> Void)

  /// Return a tuple: (installationID, authenticationToken) for success result
  func installationID(completion: @escaping (Result<(String, String), Error>) -> Void)
}

extension InstallationsProtocol {
  func installationID(completion: @escaping (Result<(String, String), Error>) -> Void) {
    var authTokenComplete = ""
    var intallationComplete: String?
    var errorComplete: Error?

    let workingQueue = DispatchQueue(label: "com.google.firebase.session.getIntallation")

    workingQueue.async {
      authToken { (authTokenResult: InstallationsAuthTokenResult?, error: Error?) in
        authTokenComplete = authTokenResult?.authToken ?? ""
      }
    }

    workingQueue.async {
      installationID { (installationID: String?, error: Error?) in
        if let installationID = installationID {
          intallationComplete = installationID
        } else if let error = error {
          errorComplete = error
        }
      }
    }

    workingQueue.sync(flags: DispatchWorkItemFlags.barrier) {
      if let installationID = intallationComplete {
        completion(.success((installationID, authTokenComplete)))
      } else if let error = errorComplete {
        completion(.failure(error))
      }
    }
  }
}

extension Installations: InstallationsProtocol {}
