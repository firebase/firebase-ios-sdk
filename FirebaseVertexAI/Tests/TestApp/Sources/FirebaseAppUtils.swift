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

import FirebaseCore

extension FirebaseApp {
  /// Configures a Firebase app with the specified name and Google Service Info plist file name.
  ///
  /// - Parameters:
  ///   - appName: The Firebase app's name; see ``FirebaseAppNames`` for app names with special
  ///     meanings in the TestApp.
  ///   - plistName: The file name of the Google Service Info plist, excluding the file extension;
  ///     for the default app this is typically called `GoogleService-Info` but any file name may be
  ///     used for other apps.
  static func configure(appName: String, plistName: String) {
    assert(!plistName.hasSuffix(".plist"), "The .plist file extension must be omitted.")
    guard let plistPath =
      Bundle.main.path(forResource: plistName, ofType: "plist") else {
      fatalError("The file '\(plistName).plist' was not found.")
    }
    guard let options = FirebaseOptions(contentsOfFile: plistPath) else {
      fatalError("Failed to parse options from '\(plistName).plist'.")
    }
    FirebaseApp.configure(name: appName, options: options)
  }
}
