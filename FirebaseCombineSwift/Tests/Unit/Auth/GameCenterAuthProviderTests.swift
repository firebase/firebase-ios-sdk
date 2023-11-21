// Copyright 2021 Google LLC
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

import Combine
import FirebaseAuth
import Foundation
import GameKit
import XCTest

class GameCenterAuthProviderTests: XCTestCase {
  override class func setUp() {
    FirebaseApp.configureForTests()
    GKLocalPlayer.mock(with: MockLocalPlayer.self)
  }

  override class func tearDown() {
    FirebaseApp.app()?.delete { success in
      if success {
        print("Shut down app successfully.")
      } else {
        print("💥 There was a problem when shutting down the app..")
      }
    }
  }

  fileprivate static let playerID = "PLAYERID"
  fileprivate static let displayName = "DISPLAYNAME"
  fileprivate static let publicKeyURL = "PUBLICKEYURL"
  fileprivate static let signature = "AAAABBBBCCCC"
  fileprivate static let salt = "AAAA"
  fileprivate static let timestamp: UInt64 = 12_345_678

  class MockLocalPlayer: GKLocalPlayer {
    static var _local: MockLocalPlayer!
    override class var local: GKLocalPlayer { _local }

    override var playerID: String { GameCenterAuthProviderTests.playerID }
    override var alias: String { GameCenterAuthProviderTests.displayName }
    override var displayName: String { GameCenterAuthProviderTests.displayName }

    var _isAuthenticated: Bool = true
    override var isAuthenticated: Bool { _isAuthenticated }

    var _errorIdentityVerificationSignature: NSError?
    override func generateIdentityVerificationSignature(completionHandler: ((URL?, Data?, Data?,
                                                                             UInt64,
                                                                             Error?) -> Void)? =
        nil) {
      let url = URL(string: GameCenterAuthProviderTests.publicKeyURL)
      let signature = Data(base64Encoded: GameCenterAuthProviderTests.signature)
      let salt = Data(base64Encoded: GameCenterAuthProviderTests.salt)
      let timestamp = GameCenterAuthProviderTests.timestamp

      if _errorIdentityVerificationSignature != nil {
        completionHandler?(nil, nil, nil, 0, _errorIdentityVerificationSignature)
      } else {
        completionHandler?(url, signature, salt, timestamp, nil)
      }
    }
  }

  class MockAuthBackend: AuthBackendImplementationMock {}

  // TODO(#10767) - Restore two tests in this file.
  func SKIPtestGetCredentialWithLocalPlayer() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())
    MockLocalPlayer._local = MockLocalPlayer()

    var cancellables = Set<AnyCancellable>()
    let getCredentialExpectation = expectation(description: "Get credential")

    // when
    GameCenterAuthProvider.getCredential()
      .sink { completion in
        switch completion {
        case .finished:
          print("Finished")
        case let .failure(error):
          XCTFail("💥 Something went wrong: \(error)")
        }
      } receiveValue: { credential in
        do {
          XCTAssertTrue(Thread.isMainThread)

          let gameCenterCredential =
            try XCTUnwrap(credential as? FIRGameCenterAuthCredential)
          XCTAssertEqual(gameCenterCredential.displayName, Self.displayName)
          XCTAssertEqual(gameCenterCredential.playerID, Self.playerID)
          XCTAssertEqual(
            gameCenterCredential.publicKeyURL.absoluteString,
            Self.publicKeyURL
          )
          XCTAssertEqual(gameCenterCredential.timestamp, Self.timestamp)
          XCTAssertEqual(gameCenterCredential.salt.base64EncodedString(), Self.salt)
          XCTAssertEqual(
            gameCenterCredential.signature.base64EncodedString(),
            Self.signature
          )

        } catch {
          XCTFail("💥 Expect non-nil OAuth credential: \(error)")
        }

        getCredentialExpectation.fulfill()
      }
      .store(in: &cancellables)

    // then
    wait(for: [getCredentialExpectation], timeout: expectationTimeout)
  }

  func testGetCredentialPlayerNotAuthenticatedWithLocalPlayer() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())
    MockLocalPlayer._local = MockLocalPlayer()
    MockLocalPlayer._local._isAuthenticated = false

    var cancellables = Set<AnyCancellable>()
    let getCredentialExpectation = expectation(description: "Get credential")

    // when
    GameCenterAuthProvider.getCredential()
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, AuthErrorCode.localPlayerNotAuthenticated.rawValue)

          getCredentialExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [getCredentialExpectation], timeout: expectationTimeout)
  }

  // TODO(#10767) - Restore
  func SKIPtestGetCredentialInvalidPlayerWithLocalPlayer() {
    // given
    FIRAuthBackend.setBackendImplementation(MockAuthBackend())
    MockLocalPlayer._local = MockLocalPlayer()
    MockLocalPlayer._local
      ._errorIdentityVerificationSignature = GKError(.invalidPlayer) as NSError

    var cancellables = Set<AnyCancellable>()
    let getCredentialExpectation = expectation(description: "Get credential")

    // when
    GameCenterAuthProvider.getCredential()
      .sink { completion in
        if case let .failure(error as NSError) = completion {
          XCTAssertEqual(error.code, GKError.invalidPlayer.rawValue)

          getCredentialExpectation.fulfill()
        }
      } receiveValue: { authDataResult in
        XCTFail("💥 result unexpected")
      }
      .store(in: &cancellables)

    // then
    wait(for: [getCredentialExpectation], timeout: expectationTimeout)
  }
}
