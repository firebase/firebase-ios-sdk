// Copyright 2026 Google LLC
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
import XCTest

@testable import FirebaseAuth

/// Concurrency tests for `User` properties that `update(withGetAccountInfoResponse:)` replaces.
///
/// These tests rarely crash on their own, as the race window is a few instructions wide. Run
/// them with Thread Sanitizer enabled to detect unsynchronized access.
/// See https://github.com/firebase/firebase-ios-sdk/issues/16975.
class UserPropertyThreadSafetyTests: XCTestCase {
  private let kCreationDate = Date(timeIntervalSince1970: 1_505_858_500)
  private let kLastSignInDate = Date(timeIntervalSince1970: 1_505_858_583)
  private let kIterations = 2000

  /// Reads `metadata` on several threads while `update(withGetAccountInfoResponse:)` replaces it.
  func testConcurrentMetadataReadDuringUpdate() throws {
    let user = makeUser()
    let response = try makeGetAccountInfoResponse()
    user.update(withGetAccountInfoResponse: response)

    DispatchQueue.concurrentPerform(iterations: 5) { index in
      for _ in 0 ..< kIterations {
        if index == 0 {
          user.update(withGetAccountInfoResponse: response)
        } else {
          _ = user.metadata.creationDate
        }
      }
    }

    XCTAssertEqual(user.metadata.creationDate, kCreationDate)
    XCTAssertEqual(user.metadata.lastSignInDate, kLastSignInDate)
  }

  #if os(iOS) || os(macOS)
    /// Reads `multiFactor` on several threads while `update(withGetAccountInfoResponse:)`
    /// replaces it.
    func testConcurrentMultiFactorReadDuringUpdate() throws {
      let user = makeUser()
      let response = try makeGetAccountInfoResponse()
      user.update(withGetAccountInfoResponse: response)

      DispatchQueue.concurrentPerform(iterations: 5) { index in
        for _ in 0 ..< kIterations {
          if index == 0 {
            user.update(withGetAccountInfoResponse: response)
          } else {
            _ = user.multiFactor.enrolledFactors
          }
        }
      }

      XCTAssertEqual(user.multiFactor.enrolledFactors.count, 1)
    }

    /// Archives the user, as `Auth` does when it saves the user to the keychain, while
    /// `update(withGetAccountInfoResponse:)` runs. `encode(with:)` reads `multiFactor` while it
    /// holds `propertyAccessQueue`.
    func testConcurrentArchiveDuringUpdate() throws {
      let user = makeUser()
      let response = try makeGetAccountInfoResponse()
      user.update(withGetAccountInfoResponse: response)

      DispatchQueue.concurrentPerform(iterations: 2) { index in
        for _ in 0 ..< kIterations / 4 {
          if index == 0 {
            user.update(withGetAccountInfoResponse: response)
          } else {
            _ = try? NSKeyedArchiver.archivedData(withRootObject: user,
                                                  requiringSecureCoding: true)
          }
        }
      }

      let data = try NSKeyedArchiver.archivedData(withRootObject: user,
                                                  requiringSecureCoding: true)
      let unarchived = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: User.self,
                                                                        from: data))
      XCTAssertEqual(unarchived.metadata.creationDate, kCreationDate)
      XCTAssertEqual(unarchived.multiFactor.enrolledFactors.count, 1)
    }
  #endif

  // MARK: - Helpers

  private func makeUser() -> User {
    let tokenService = SecureTokenService(
      withRequestConfiguration: nil,
      accessToken: "accessToken",
      accessTokenExpirationDate: Date().addingTimeInterval(3600),
      refreshToken: "refreshToken"
    )
    return User(withTokenService: tokenService,
                backend: AuthBackend(rpcIssuer: AuthBackendRPCIssuer()))
  }

  private func makeGetAccountInfoResponse() throws -> GetAccountInfoResponse {
    let mfaInfo: [[String: AnyHashable]] = [[
      "phoneInfo": "+16505551234",
      "mfaEnrollmentId": "enrollmentID",
      "displayName": "phone",
    ]]
    let userInfo: [String: AnyHashable] = [
      "localId": "localID",
      "createdAt": String(Int(kCreationDate.timeIntervalSince1970 * 1000)),
      "lastLoginAt": String(Int(kLastSignInDate.timeIntervalSince1970 * 1000)),
      "mfaInfo": mfaInfo,
    ]
    return try GetAccountInfoResponse(dictionary: ["users": [userInfo]])
  }
}
