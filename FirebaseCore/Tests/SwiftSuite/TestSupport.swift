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

import FirebaseCore
import FirebaseCoreTestHooks
import Foundation
import XCTest

/// Values used in the test GoogleService-Info.plist files.
enum TestValues {
  static let apiKey = "correct_api_key"
  static let bundleID = "com.google.FirebaseSDKTests"
  static let clientID = "correct_client_id"
  static let gcmSenderID = "correct_gcm_sender_id"
  static let projectID = "abc-xyz-123"
  static let googleAppID = "1:123:ios:123abc"
  static let databaseURL = "https://abc-xyz-123.firebaseio.com"
  static let storageBucket = "project-id-123.storage.firebase.com"

  /// The contents of a valid GoogleService-Info.plist.
  static var serviceInfo: [String: Any] {
    [
      "API_KEY": apiKey,
      "BUNDLE_ID": bundleID,
      "CLIENT_ID": clientID,
      "DATABASE_URL": databaseURL,
      "GCM_SENDER_ID": gcmSenderID,
      "GOOGLE_APP_ID": googleAppID,
      "PROJECT_ID": projectID,
      "STORAGE_BUCKET": storageBucket,
    ]
  }
}

/// Keys of the analytics flags in GoogleService-Info.plist and Info.plist. They're public values
/// that must never change.
enum AnalyticsKeys {
  static let measurementEnabled = "IS_MEASUREMENT_ENABLED"
  static let collectionEnabled = "FIREBASE_ANALYTICS_COLLECTION_ENABLED"
  static let collectionDeactivated = "FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED"
}

/// A temporary directory that FirebaseCore searches for GoogleService-Info.plist instead of the
/// app's bundles. This replaces mocking `FIRBundleUtil` with OCMock.
final class TemporaryServiceInfoBundle {
  let directory: URL

  /// Creates an empty bundle directory.
  init() throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FirebaseCoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  var plistURL: URL { directory.appendingPathComponent("GoogleService-Info.plist") }

  /// Writes `contents` as GoogleService-Info.plist.
  func writeServiceInfo(_ contents: [String: Any] = TestValues.serviceInfo) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: contents,
                                                  format: .xml,
                                                  options: 0)
    try data.write(to: plistURL)
  }

  /// Writes a GoogleService-Info.plist that isn't a valid property list.
  func writeInvalidServiceInfo() throws {
    try Data("not a property list".utf8).write(to: plistURL)
  }

  /// Makes FirebaseCore search only this directory for GoogleService-Info.plist.
  func install() throws {
    let bundle = try XCTUnwrap(Bundle(path: directory.path))
    CoreTestHooks.setRelevantBundles([bundle])
  }

  deinit {
    try? FileManager.default.removeItem(at: directory)
  }
}

/// Restores FirebaseCore's global state that the tests change.
func resetCoreTestState() {
  CoreTestHooks.setRelevantBundles(nil)
  FirebaseOptions.resetDefaultOptions()
}
