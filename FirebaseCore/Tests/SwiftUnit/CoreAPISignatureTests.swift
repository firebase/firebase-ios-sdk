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

// MARK: This file pins the exact Swift signatures of the FirebaseCore public API.

// FirebaseCore is being reimplemented in Swift, and its public Swift API must not change.
// `CoreAPITests.swift` checks that typical call sites compile. This file is stricter: it binds
// every public declaration to an explicitly typed value, so a change to a parameter type,
// optionality, `@Sendable`, `async`, mutability, or `open`-ness fails to compile.
// None of this code runs; compiling it is the test.

import Foundation

import FirebaseCore

// MARK: - Subclassing (the public classes are `open`)

private final class SubclassedApp: FirebaseApp {
  override var name: String { "subclass" }
  override var isDataCollectionDefaultEnabled: Bool {
    get { false }
    set {}
  }
}

private final class SubclassedOptions: FirebaseOptions {
  override var apiKey: String? {
    get { "key" }
    set {}
  }
}

private final class SubclassedTimestamp: Timestamp, @unchecked Sendable {
  override func dateValue() -> Date { Date() }
}

private final class SubclassedConfiguration: FirebaseConfiguration {
  override func loggerLevel() -> FirebaseLoggerLevel { .debug }
}

// MARK: - Protocol requirements satisfied by the public types

/// Firestore relies on `Timestamp.init(seconds:nanoseconds:)` satisfying a protocol initializer
/// requirement (`Timestamp+Codable.swift`).
private protocol SecondsNanosecondsInitializable {
  init(seconds: Int64, nanoseconds: Int32)
}

extension Timestamp: SecondsNanosecondsInitializable {}

private func requireSendable<T: Sendable>(_: T.Type) {}
private func requireNSCopying<T: NSCopying>(_: T.Type) {}
private func requireNSObject<T: NSObject>(_: T.Type) {}
private func requireType<T>(_: T, _: T.Type) {}

final class CoreAPISignatureTests {
  func signatures() async {
    // MARK: - FirebaseApp

    requireNSObject(FirebaseApp.self)
    let _: () -> Void = FirebaseApp.configure
    let _: (FirebaseOptions) -> Void = FirebaseApp.configure(options:)
    let _: (String, FirebaseOptions) -> Void = FirebaseApp.configure(name:options:)
    let _: () -> FirebaseApp? = FirebaseApp.app
    let _: (String) -> FirebaseApp? = FirebaseApp.app(name:)
    let _: [String: FirebaseApp]? = FirebaseApp.allApps
    let _: (FirebaseApp) -> (@escaping @Sendable (Bool) -> Void) -> Void = FirebaseApp.delete(_:)
    let _: KeyPath<FirebaseApp, String> = \FirebaseApp.name
    let _: KeyPath<FirebaseApp, FirebaseOptions> = \FirebaseApp.options
    let _: ReferenceWritableKeyPath<FirebaseApp, Bool> = \FirebaseApp.isDataCollectionDefaultEnabled

    if let app = FirebaseApp.app() {
      let deleted: Bool = await app.delete()
      _ = deleted
    }

    // MARK: - FirebaseOptions

    requireNSCopying(FirebaseOptions.self)
    let _: () -> FirebaseOptions? = FirebaseOptions.defaultOptions
    let _: (String) -> FirebaseOptions? = FirebaseOptions.init(contentsOfFile:)
    let _: (String, String) -> FirebaseOptions = FirebaseOptions.init(googleAppID:gcmSenderID:)
    let _: ReferenceWritableKeyPath<FirebaseOptions, String?> = \FirebaseOptions.apiKey
    let _: ReferenceWritableKeyPath<FirebaseOptions, String> = \FirebaseOptions.bundleID
    let _: ReferenceWritableKeyPath<FirebaseOptions, String?> = \FirebaseOptions.clientID
    let _: ReferenceWritableKeyPath<FirebaseOptions, String> = \FirebaseOptions.gcmSenderID
    let _: ReferenceWritableKeyPath<FirebaseOptions, String?> = \FirebaseOptions.projectID
    let _: ReferenceWritableKeyPath<FirebaseOptions, String> = \FirebaseOptions.googleAppID
    let _: ReferenceWritableKeyPath<FirebaseOptions, String?> = \FirebaseOptions.databaseURL
    let _: ReferenceWritableKeyPath<FirebaseOptions, String?> = \FirebaseOptions.storageBucket
    let _: ReferenceWritableKeyPath<FirebaseOptions, String?> = \FirebaseOptions.appGroupID

    let options = FirebaseOptions(googleAppID: "1:123:ios:abc", gcmSenderID: "123")
    let copied: Any = options.copy()
    _ = copied

    // MARK: - FirebaseConfiguration

    requireNSObject(FirebaseConfiguration.self)
    requireType(FirebaseConfiguration.shared, FirebaseConfiguration.self)
    let _: (FirebaseConfiguration) -> (FirebaseLoggerLevel) -> Void =
      FirebaseConfiguration.setLoggerLevel(_:)
    let _: (FirebaseConfiguration) -> () -> FirebaseLoggerLevel = FirebaseConfiguration.loggerLevel

    // MARK: - FirebaseLoggerLevel

    requireSendable(FirebaseLoggerLevel.self)
    let _: FirebaseLoggerLevel = .min
    let _: FirebaseLoggerLevel = .max
    let _: FirebaseLoggerLevel? = FirebaseLoggerLevel(rawValue: 3)
    let _: Int = FirebaseLoggerLevel.error.rawValue
    let level = FirebaseLoggerLevel.notice
    switch level {
    case .error: break
    case .warning: break
    case .notice: break
    case .info: break
    case .debug: break
    @unknown default: break
    }

    // MARK: - Timestamp

    requireSendable(Timestamp.self)
    requireNSCopying(Timestamp.self)
    let _: (Int64, Int32) -> Timestamp = Timestamp.init(seconds:nanoseconds:)
    let _: (Date) -> Timestamp = Timestamp.init(date:)
    let _: () -> Timestamp = Timestamp.init
    let _: (Timestamp) -> () -> Date = Timestamp.dateValue
    let _: (Timestamp) -> (Timestamp) -> ComparisonResult = Timestamp.compare(_:)
    let _: KeyPath<Timestamp, Int64> = \Timestamp.seconds
    let _: KeyPath<Timestamp, Int32> = \Timestamp.nanoseconds

    // MARK: - FirebaseVersion

    let _: () -> String = FirebaseVersion
    let _: String = FirebaseCore.FirebaseVersion()
    let _: FirebaseCore.FirebaseLoggerLevel = .error
  }
}
