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

private import FirebaseCoreInternal
import Foundation

/// **[Experimental]** Configuration options for a `FirebaseApp`.
///
/// > Warning: This portable implementation is for development and testing use only. The Firebase
/// > Apple SDK is only officially supported on Apple platforms.
public final class FirebaseOptions: Sendable, Equatable, Hashable {
  // MARK: - Internal Storage

  private struct Storage: Sendable, Equatable, Hashable {
    var googleAppID: String
    var gcmSenderID: String
    var apiKey: String?
    var projectID: String?
    var storageBucket: String?
    var bundleID: String
    var clientID: String?
    var databaseURL: String?
    var appGroupID: String?
  }

  private let storage: UnfairLock<Storage>
  private let isEditingLocked: Bool

  private static let editingLockedMessage =
    "FirebaseOptions cannot be modified after being used to configure a FirebaseApp."

  // MARK: - Properties

  /// **[Experimental]** The Google App ID that is used to uniquely identify an instance of an app.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var googleAppID: String {
    get { storage.withLock { $0.googleAppID } }
    set {
      precondition(!isEditingLocked, Self.editingLockedMessage)
      storage.withLock { $0.googleAppID = newValue }
    }
  }

  /// **[Experimental]** The Project Number from the Google Developer's console used to configure
  /// Firebase Cloud Messaging.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var gcmSenderID: String {
    get { storage.withLock { $0.gcmSenderID } }
    set {
      precondition(!isEditingLocked, Self.editingLockedMessage)
      storage.withLock { $0.gcmSenderID = newValue }
    }
  }

  /// **[Experimental]** An API key used for authenticating requests from your app.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var apiKey: String? {
    get { storage.withLock { $0.apiKey } }
    set {
      precondition(!isEditingLocked, Self.editingLockedMessage)
      storage.withLock { $0.apiKey = newValue }
    }
  }

  /// **[Experimental]** The Project ID from the Firebase console.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var projectID: String? {
    get { storage.withLock { $0.projectID } }
    set {
      precondition(!isEditingLocked, Self.editingLockedMessage)
      storage.withLock { $0.projectID = newValue }
    }
  }

  /// **[Experimental]** The Google Cloud Storage bucket name.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var storageBucket: String? {
    get { storage.withLock { $0.storageBucket } }
    set {
      precondition(!isEditingLocked, Self.editingLockedMessage)
      storage.withLock { $0.storageBucket = newValue }
    }
  }

  /// **[Experimental]** The bundle ID for the application.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var bundleID: String {
    get { storage.withLock { $0.bundleID } }
    set {
      precondition(!isEditingLocked, Self.editingLockedMessage)
      storage.withLock { $0.bundleID = newValue }
    }
  }

  /// **[Experimental]** The OAuth2 client ID used to authenticate Google users.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var clientID: String? {
    get { storage.withLock { $0.clientID } }
    set {
      precondition(!isEditingLocked, Self.editingLockedMessage)
      storage.withLock { $0.clientID = newValue }
    }
  }

  /// **[Experimental]** The database root URL.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var databaseURL: String? {
    get { storage.withLock { $0.databaseURL } }
    set {
      precondition(!isEditingLocked, Self.editingLockedMessage)
      storage.withLock { $0.databaseURL = newValue }
    }
  }

  /// **[Experimental]** The App Group identifier to share data between the application and
  /// application extensions.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  public var appGroupID: String? {
    get { storage.withLock { $0.appGroupID } }
    set {
      precondition(!isEditingLocked, Self.editingLockedMessage)
      storage.withLock { $0.appGroupID = newValue }
    }
  }

  // MARK: - Initializers

  private init(storage: Storage, isEditingLocked: Bool = false) {
    self.storage = UnfairLock(storage)
    self.isEditingLocked = isEditingLocked
  }

  /// **[Experimental]** Initializes a customized instance of `FirebaseOptions` with required
  /// fields.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameters:
  ///   - googleAppID: The Google App ID for the Firebase app.
  ///   - gcmSenderID: The GCM Sender ID (project number) for the Firebase app.
  public init(googleAppID: String, gcmSenderID: String) {
    storage = UnfairLock(
      Storage(
        googleAppID: googleAppID,
        gcmSenderID: gcmSenderID,
        bundleID: Bundle.main.bundleIdentifier ?? ""
      )
    )
    isEditingLocked = false
  }

  /// Initializes a customized instance of `FirebaseOptions` with programmatic fields.
  ///
  /// - Parameters:
  ///   - googleAppID: The Google App ID for the Firebase app.
  ///   - gcmSenderID: The GCM Sender ID (project number) for the Firebase app.
  ///   - apiKey: An API key used for authenticating requests from your app.
  ///   - projectID: The Project ID from the Firebase console.
  ///   - storageBucket: The Google Cloud Storage bucket name.
  ///   - bundleID: The bundle ID for the application.
  ///   - clientID: The OAuth2 client ID used to authenticate Google users.
  ///   - databaseURL: The database root URL.
  ///   - appGroupID: The App Group identifier.
  package convenience init(googleAppID: String,
                           gcmSenderID: String,
                           apiKey: String?,
                           projectID: String? = nil,
                           storageBucket: String? = nil,
                           bundleID: String? = nil,
                           clientID: String? = nil,
                           databaseURL: String? = nil,
                           appGroupID: String? = nil) {
    self.init(
      storage: Storage(
        googleAppID: googleAppID,
        gcmSenderID: gcmSenderID,
        apiKey: apiKey,
        projectID: projectID,
        storageBucket: storageBucket,
        bundleID: bundleID ?? Bundle.main.bundleIdentifier ?? "",
        clientID: clientID,
        databaseURL: databaseURL,
        appGroupID: appGroupID
      )
    )
  }

  /// **[Experimental]** Initializes a customized instance of `FirebaseOptions` from the file at
  /// the given plist file path.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameter plistPath: The path to a `GoogleService-Info.plist` file.
  public convenience init?(contentsOfFile plistPath: String) {
    let fileURL = URL(fileURLWithPath: plistPath)
    guard let data = try? Data(contentsOf: fileURL),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
          let dict = plist as? [String: Any],
          let googleAppID = dict["GOOGLE_APP_ID"] as? String,
          !googleAppID.isEmpty else {
      return nil
    }
    let gcmSenderID = (dict["GCM_SENDER_ID"] as? String) ?? ""
    self.init(
      storage: Storage(
        googleAppID: googleAppID,
        gcmSenderID: gcmSenderID,
        apiKey: dict["API_KEY"] as? String,
        projectID: dict["PROJECT_ID"] as? String,
        storageBucket: dict["STORAGE_BUCKET"] as? String,
        bundleID: (dict["BUNDLE_ID"] as? String) ?? Bundle.main.bundleIdentifier ?? "",
        clientID: dict["CLIENT_ID"] as? String,
        databaseURL: dict["DATABASE_URL"] as? String,
        appGroupID: nil
      )
    )
  }

  // MARK: - Default Options

  /// **[Experimental]** Returns the default options loaded from `GoogleService-Info.plist`, or
  /// `nil` if no valid plist is found.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Returns: A `FirebaseOptions` instance, or `nil` if not found.
  public static func defaultOptions() -> FirebaseOptions? {
    if let envPath = ProcessInfo.processInfo.environment["GOOGLE_SERVICE_INFO_PATH"],
       !envPath.isEmpty {
      return FirebaseOptions(contentsOfFile: envPath)
    }
    if let bundlePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
      return FirebaseOptions(contentsOfFile: bundlePath)
    }
    let cwdPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("GoogleService-Info.plist").path
    if FileManager.default.fileExists(atPath: cwdPath) {
      return FirebaseOptions(contentsOfFile: cwdPath)
    }
    return nil
  }

  // MARK: - Snapshot Copy

  /// Creates a snapshot copy of this `FirebaseOptions` instance.
  ///
  /// - Parameter lockEditing: If `true`, locks the returned copy against further mutations.
  /// - Returns: A new `FirebaseOptions` instance containing the same configuration values.
  package func copy(lockEditing: Bool = false) -> FirebaseOptions {
    FirebaseOptions(
      storage: storage.value(),
      isEditingLocked: lockEditing || isEditingLocked
    )
  }

  // MARK: - Equatable & Hashable

  /// **[Experimental]** Compares two `FirebaseOptions` instances for value equality.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameters:
  ///   - lhs: The first `FirebaseOptions` instance.
  ///   - rhs: The second `FirebaseOptions` instance.
  /// - Returns: `true` if all option properties are equal.
  public static func == (lhs: FirebaseOptions, rhs: FirebaseOptions) -> Bool {
    lhs.storage.value() == rhs.storage.value()
  }

  /// **[Experimental]** Hashes the option properties of this instance into the given hasher.
  ///
  /// > Warning: This portable implementation is for development and testing use only. The Firebase
  /// > Apple SDK is only officially supported on Apple platforms.
  ///
  /// - Parameter hasher: The hasher to use when combining the components of this instance.
  public func hash(into hasher: inout Hasher) {
    hasher.combine(storage.value())
  }
}
