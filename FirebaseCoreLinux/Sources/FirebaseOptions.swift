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

/// The options used to configure a Firebase app.
public struct FirebaseOptions: Equatable, Hashable {
    /// An API key used for authenticating requests from your app.
    public var apiKey: String?

    /// The bundle ID for the application. Defaults to `Bundle.main.bundleIdentifier` when not set.
    public var bundleID: String

    /// The OAuth2 client ID for the application.
    public var clientID: String?

    /// The Project Number from the Google Developer's console.
    public var gcmSenderID: String

    /// The Project ID from the Firebase console.
    public var projectID: String?

    /// The Google App ID that is used to uniquely identify an instance of an app.
    public var googleAppID: String

    /// The database root URL.
    public var databaseURL: String?

    /// The Google Cloud Storage bucket name.
    public var storageBucket: String?

    /// The App Group identifier to share data between the application and the application extensions.
    public var appGroupID: String?

    /// Returns the default options. The first time this is called it synchronously reads
    /// GoogleService-Info.plist from disk.
    public static func defaultOptions() -> FirebaseOptions? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            return nil
        }
        return FirebaseOptions(contentsOfFile: path)
    }

    /// Initializes a customized instance of `FirebaseOptions` with required fields.
    public init(googleAppID: String, gcmSenderID: String) {
        self.googleAppID = googleAppID
        self.gcmSenderID = gcmSenderID
        self.bundleID = Bundle.main.bundleIdentifier ?? ""
    }

    /// Initializes a customized instance of `FirebaseOptions` from the file at the given plist file path.
    public init?(contentsOfFile plistPath: String) {
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        guard let googleAppID = plist["GOOGLE_APP_ID"] as? String else {
            return nil
        }

        self.googleAppID = googleAppID
        self.gcmSenderID = plist["GCM_SENDER_ID"] as? String ?? ""
        self.apiKey = plist["API_KEY"] as? String
        self.bundleID = plist["BUNDLE_ID"] as? String ?? Bundle.main.bundleIdentifier ?? ""
        self.clientID = plist["CLIENT_ID"] as? String
        self.projectID = plist["PROJECT_ID"] as? String
        self.databaseURL = plist["DATABASE_URL"] as? String
        self.storageBucket = plist["STORAGE_BUCKET"] as? String
    }
}
