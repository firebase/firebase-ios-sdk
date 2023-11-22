// Copyright 2023 Google LLC
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

@testable import FirebaseAppDistributionInternal
@testable import FirebaseInstallations
import Foundation

// This is needed because importing the setter from FIRInstallationsAuthTokenResultInternal.h in
// the bridging error results in errors.
extension InstallationsAuthTokenResult {
  convenience init(token: String, expirationDate: Date) {
    self.init()
    // TODO(tejasd): If needed for tests, explore a way to set the get only properties.
  }
}

class FakeInstallations: InstallationsProtocol {
  let fakeErrorDomain = "test.failure.domain"
  let fakeInstallationID = "this-id-is-fake"
  let fakeAuthToken = "this-is-a-fake-auth-token"

  enum TestCase {
    case success
    case authTokenFailure
    case installationIDFailure
  }

  var testCase: TestCase

  required init(testCase: TestCase) {
    self.testCase = testCase
  }

  func authToken(completion: @escaping (InstallationsAuthTokenResult?, Error?) -> Void) {
    switch testCase {
    case .success:
      let authToken = InstallationsAuthTokenResult(token: fakeAuthToken, expirationDate: Date())
      completion(authToken, nil)
    case .authTokenFailure:
      let error = NSError(domain: fakeErrorDomain, code: 1)
      completion(nil, error)
    default:
      completion(nil, nil)
    }
  }

  func installationID(completion: @escaping (String?, Error?) -> Void) {
    switch testCase {
    case .success:
      completion(fakeInstallationID, nil)
    case .installationIDFailure:
      let error = NSError(domain: fakeErrorDomain, code: 1)
      completion(nil, error)
    default:
      completion(nil, nil)
    }
  }
}
