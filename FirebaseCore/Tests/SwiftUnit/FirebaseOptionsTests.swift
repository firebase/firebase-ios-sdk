// Copyright 2020 Google LLC
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

@testable import FirebaseCore
import XCTest

class FirebaseOptionsTests: XCTestCase {
  func testDefaultOptions() throws {
    let options = try XCTUnwrap(
      FirebaseOptions.defaultOptions(),
      "Default options could not be unwrapped"
    )
    assertOptionsMatchDefaultOptions(options: options)
  }

  func testInitWithContentsOfFile() throws {
    let bundle = try XCTUnwrap(
      Bundle(for: type(of: self)),
      "Could not find bundle"
    )

    let path = try XCTUnwrap(
      bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
      "Could not find path for file"
    )

    let options = FirebaseOptions(contentsOfFile: path)
    XCTAssertNotNil(options)
  }

  func testInitWithInvalidSourceFile() {
    let invalidPath = "path/to/non-existing/plist"
    let options = FirebaseOptions(contentsOfFile: invalidPath)
    XCTAssertNil(options)
  }

  func testInitWithCustomFields() throws {
    let googleAppID = "5:678:ios:678def"
    let gcmSenderID = "custom_gcm_sender_id"
    let options = FirebaseOptions(googleAppID: googleAppID,
                                  gcmSenderID: gcmSenderID)

    XCTAssertEqual(options.googleAppID, googleAppID)
    XCTAssertEqual(options.gcmSenderID, gcmSenderID)

    let bundleID =
      try XCTUnwrap(Bundle.main.bundleIdentifier, "Could not retrieve bundle identifier")
    XCTAssertEqual(options.bundleID, bundleID)

    assertNullableOptionsAreEmpty(options: options)
  }

  func testCustomizedOptions() {
    let googleAppID = Constants.Options.googleAppID
    let gcmSenderID = Constants.Options.gcmSenderID
    let options = FirebaseOptions(googleAppID: googleAppID,
                                  gcmSenderID: gcmSenderID)
    options.bundleID = Constants.Options.bundleID
    options.apiKey = Constants.Options.apiKey
    options.clientID = Constants.Options.clientID
    options.projectID = Constants.Options.projectID
    options.databaseURL = Constants.Options.databaseURL
    options.storageBucket = Constants.Options.storageBucket
    options.appGroupID = Constants.Options.appGroupID

    assertOptionsMatchDefaultOptions(options: options)
  }

  func testEditingCustomOptions() {
    let googleAppID = Constants.Options.googleAppID
    let gcmSenderID = Constants.Options.gcmSenderID
    let options = FirebaseOptions(googleAppID: googleAppID,
                                  gcmSenderID: gcmSenderID)

    let newGCMSenderID = "newgcmSenderID"
    options.gcmSenderID = newGCMSenderID
    XCTAssertEqual(options.gcmSenderID, newGCMSenderID)

    let newGoogleAppID = "newGoogleAppID"
    options.googleAppID = newGoogleAppID
    XCTAssertEqual(options.googleAppID, newGoogleAppID)

    XCTAssertNil(options.appGroupID)
    options.appGroupID = Constants.Options.appGroupID
    XCTAssertEqual(options.appGroupID, Constants.Options.appGroupID)
  }

  func testCopyingProperties() {
    let googleAppID = Constants.Options.googleAppID
    let gcmSenderID = Constants.Options.gcmSenderID
    let options = FirebaseOptions(googleAppID: googleAppID,
                                  gcmSenderID: gcmSenderID)
    var apiKey = "123456789"
    options.apiKey = apiKey
    XCTAssertEqual(options.apiKey, apiKey)
    apiKey = "000000000"
    XCTAssertNotEqual(options.apiKey, apiKey)
  }

  func testCopying() {
    let options = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                  gcmSenderID: Constants.Options.gcmSenderID)
    options.apiKey = Constants.Options.apiKey
    options.projectID = Constants.Options.projectID

    // Set a custom app group ID to verify it is copied (since it's not in the dictionary)
    let customAppGroupID = "customAppGroupID"
    options.appGroupID = customAppGroupID

    guard let copiedOptions = options.copy() as? FirebaseOptions else {
      XCTFail("Copy failed to return a FirebaseOptions instance")
      return
    }

    XCTAssertEqual(copiedOptions.googleAppID, options.googleAppID)
    XCTAssertEqual(copiedOptions.gcmSenderID, options.gcmSenderID)
    XCTAssertEqual(copiedOptions.apiKey, options.apiKey)
    XCTAssertEqual(copiedOptions.projectID, options.projectID)
    XCTAssertEqual(copiedOptions.appGroupID, customAppGroupID)

    // Verify deep copy / independence
    options.apiKey = "newApiKey"
    options.appGroupID = "newAppGroupID"

    XCTAssertEqual(copiedOptions.apiKey, Constants.Options.apiKey)
    XCTAssertEqual(copiedOptions.appGroupID, customAppGroupID)
  }

  func testOptionsEquality() throws {
    let defaultOptions1 = try XCTUnwrap(
      FirebaseOptions.defaultOptions(),
      "Default options could not be unwrapped"
    )
    let defaultOptions2 = try XCTUnwrap(
      FirebaseOptions.defaultOptions(),
      "Default options could not be unwrapped"
    )

    XCTAssertEqual(defaultOptions1.hash, defaultOptions2.hash)
    XCTAssertTrue(defaultOptions1.isEqual(defaultOptions2))

    let plainOptions = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                       gcmSenderID: Constants.Options.gcmSenderID)
    XCTAssertFalse(plainOptions.isEqual(defaultOptions1))
  }

  func testEqualityAndHashWithModifications() {
    let options1 = FirebaseOptions(googleAppID: "appID", gcmSenderID: "senderID")
    let options2 = FirebaseOptions(googleAppID: "appID", gcmSenderID: "senderID")

    // Initial state
    XCTAssertEqual(options1, options2)
    XCTAssertEqual(options1.hash, options2.hash)

    // Modify dictionary-backed property
    options1.apiKey = "someKey"
    XCTAssertNotEqual(options1, options2)

    // Revert
    options1.apiKey = nil
    XCTAssertEqual(options1, options2)
    XCTAssertEqual(options1.hash, options2.hash)

    // Modify manual property
    options1.appGroupID = "group1"
    XCTAssertNotEqual(options1, options2)

    // Revert
    options1.appGroupID = nil
    XCTAssertEqual(options1, options2)
    XCTAssertEqual(options1.hash, options2.hash)
  }

  // MARK: - Helpers

  private func assertOptionsMatchDefaultOptions(options: FirebaseOptions) {
    XCTAssertEqual(options.apiKey, Constants.Options.apiKey)
    XCTAssertEqual(options.bundleID, Constants.Options.bundleID)
    XCTAssertEqual(options.clientID, Constants.Options.clientID)
    XCTAssertEqual(options.gcmSenderID, Constants.Options.gcmSenderID)
    XCTAssertEqual(options.projectID, Constants.Options.projectID)
    XCTAssertEqual(options.googleAppID, Constants.Options.googleAppID)
    XCTAssertEqual(options.databaseURL, Constants.Options.databaseURL)
    XCTAssertEqual(options.storageBucket, Constants.Options.storageBucket)
    XCTAssertNil(options.appGroupID)
  }

  private func assertNullableOptionsAreEmpty(options: FirebaseOptions) {
    XCTAssertNil(options.apiKey)
    XCTAssertNil(options.clientID)
    XCTAssertNil(options.projectID)
    XCTAssertNil(options.databaseURL)
    XCTAssertNil(options.storageBucket)
    XCTAssertNil(options.appGroupID)
  }
}
