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

import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import XCTest

class StorageIntegrationCommon: XCTestCase {
  var app: FirebaseApp!
  var auth: Auth!
  var storage: Storage!
  static var configured = false
  static var once = false
  static var signedIn = false

  /// The Storage emulator to run the tests against instead of the production backend, from the
  /// `FIREBASE_STORAGE_EMULATOR_HOST` environment variable. With `FIREBASE_AUTH_EMULATOR_HOST`,
  /// the tests sign in with the Auth emulator. `Emulator/start.sh` starts both emulators with the
  /// rules that the tests need, and xcodebuild passes variables to the tests without their
  /// `TEST_RUNNER_` prefix:
  ///
  ///     TEST_RUNNER_FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 \
  ///     TEST_RUNNER_FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
  ///     xcodebuild test ...
  ///
  /// The `storage-emulator-integration-tests` job of sdk.storage.yml runs the tests this way,
  /// with the fake configuration in `Emulator/GoogleService-Info.plist`.
  static let storageEmulator = emulator(fromVariable: "FIREBASE_STORAGE_EMULATOR_HOST")
  static let authEmulator = emulator(fromVariable: "FIREBASE_AUTH_EMULATOR_HOST")

  /// The scheme, host, and port of download URLs.
  static var downloadURLOrigin: String {
    guard let storageEmulator else {
      return "https://firebasestorage.googleapis.com:443"
    }
    return "http://\(storageEmulator.host):\(storageEmulator.port)"
  }

  /// Returns the host and port of an emulator from a `host:port` environment variable.
  private static func emulator(fromVariable name: String) -> (host: String, port: Int)? {
    guard let value = ProcessInfo.processInfo.environment[name],
          let separator = value.lastIndex(of: ":"),
          let port = Int(value[value.index(after: separator)...]) else {
      return nil
    }
    return (String(value[..<separator]), port)
  }

  /// Skips a test of production behavior that the Storage emulator doesn't have.
  func skipWithStorageEmulator(because reason: String) throws {
    try XCTSkipIf(StorageIntegrationCommon.storageEmulator != nil, "The Storage emulator \(reason)")
  }

  override class func setUp() {
    if !StorageIntegrationCommon.configured {
      StorageIntegrationCommon.configured = true
      FirebaseApp.configure()
      if let storageEmulator {
        Storage.storage().useEmulator(withHost: storageEmulator.host, port: storageEmulator.port)
      }
      if let authEmulator {
        Auth.auth().useEmulator(withHost: authEmulator.host, port: authEmulator.port)
      }
    }
  }

  override func setUp() {
    super.setUp()
    app = FirebaseApp.app()
    auth = Auth.auth(app: app)
    storage = Storage.storage(app: app!)

    if !StorageIntegrationCommon.signedIn {
      signInAndWait()
    }

    if !StorageIntegrationCommon.once {
      StorageIntegrationCommon.once = true
      let setupExpectation = expectation(description: "setUp")

      let largeFiles = ["ios/public/1mb", "ios/public/1mb2"]
      let emptyFiles =
        ["ios/public/empty", "ios/public/list/a", "ios/public/list/b", "ios/public/list/prefix/c"]
      setupExpectation.expectedFulfillmentCount = largeFiles.count + emptyFiles.count

      do {
        let bundle = Bundle(for: StorageIntegrationCommon.self)
        let filePath = try XCTUnwrap(bundle.path(forResource: "1mb", ofType: "dat"),
                                     "Failed to get filePath")
        let data = try XCTUnwrap(Data(contentsOf: URL(fileURLWithPath: filePath)),
                                 "Failed to load file")

        for largeFile in largeFiles {
          let ref = storage.reference().child(largeFile)
          ref.putData(data) { result in
            self.assertResultSuccess(result)
            setupExpectation.fulfill()
          }
        }
        for emptyFile in emptyFiles {
          let ref = storage.reference().child(emptyFile)
          ref.putData(Data()) { result in
            self.assertResultSuccess(result)
            setupExpectation.fulfill()
          }
        }
        waitForExpectations()
      } catch {
        XCTFail("Error thrown setting up files in setUp")
      }
    }
  }

  override func tearDown() {
    app = nil
    storage = nil
    super.tearDown()
  }

  private func signInAndWait() {
    let expectation = self.expectation(description: #function)
    let completion = { (result: AuthDataResult?, error: Error?) in
      XCTAssertNil(error)
      StorageIntegrationCommon.signedIn = true
      print("Successfully signed in")
      expectation.fulfill()
    }
    if StorageIntegrationCommon.authEmulator != nil {
      // The Auth emulator has no users, and the rules only require a signed-in one.
      auth.signInAnonymously(completion: completion)
    } else {
      auth.signIn(withEmail: Credentials.kUserName,
                  password: Credentials.kPassword,
                  completion: completion)
    }
    waitForExpectations()
  }

  private func waitForExpectations() {
    let kTestTimeout = 60.0
    waitForExpectations(timeout: kTestTimeout,
                        handler: { error in
                          if let error {
                            print(error)
                          }
                        })
  }

  private func assertResultSuccess<T>(_ result: Result<T, Error>,
                                      file: StaticString = #file, line: UInt = #line) {
    switch result {
    case let .success(value):
      XCTAssertNotNil(value, file: file, line: line)
    case let .failure(error):
      XCTFail("Unexpected error \(error)")
    }
  }
}
