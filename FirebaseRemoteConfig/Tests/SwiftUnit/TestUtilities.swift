// Copyright 2025 Google LLC
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

enum Constants {
  static let firebaseNamespace = "firebase"
  static let perfNamespace = "fireperf"
  static let defaultFirebaseAppName = "__FIRAPP_DEFAULT"
  static let secondFirebaseAppName = "secondFIRApp"
}

public class TestUtilities {
  public static func generatedTestAppName(for testName: String) -> String {
    // Filter out any characters not valid for FIRApp's naming scheme.
    let invalidCharacters = CharacterSet.alphanumerics.inverted

    // This will result in a string with the class name, a space, and the test
    // name. We only care about the test name so split it into components and
    // return the last item.
    let friendlyTestName = testName.trimmingCharacters(in: invalidCharacters)
    let components = friendlyTestName.components(separatedBy: " ")
    return components.last ?? ""
  }

  public static func remoteConfigTestDatabasePath() -> String {
    #if os(tvOS)
      let dirPaths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
    #else
      let dirPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,
                                                         .userDomainMask, true)
    #endif
    let storageDirPath = dirPaths[0]
    let dbPath = URL(fileURLWithPath: storageDirPath)
      .appendingPathComponent("Google/RemoteConfig")
      .appendingPathComponent("test-\(Date().timeIntervalSince1970 * 1000).sqlite3").path
    removeDatabase(at: dbPath)
    return dbPath
  }

  public static func removeDatabase(at dbPath: String) {
    try? FileManager.default.removeItem(atPath: dbPath)
  }

  public static func userDefaultsTestSuiteName() -> String {
    "group.\(Bundle.main.bundleIdentifier!).test-\(Date().timeIntervalSince1970 * 1000)"
  }
}
