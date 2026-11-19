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

internal import FirebaseCore
private import FirebaseCoreInternal
import Foundation
import OpenTelemetryApi

/// Provides common OpenTelemetry attributes to be attached across telemetry signals.
enum AttributeStore {
  private static let screenName = UnfairLock<String>(CrashlyticsScreen.unknown.name)
  private static let sessionId = UnfairLock<String?>(nil)

  /// Updates the currently active screen name.
  static func setScreenName(_ name: String) {
    screenName.withLock { $0 = name }
  }

  /// Updates the currently active session ID.
  static func setSessionId(_ id: String?) {
    sessionId.withLock { $0 = id }
  }

  /// Returns the resource attributes identifying the Firebase app and host environment.
  static func resourceAttributes(options: FirebaseOptions,
                                 environment: any TelemetryEnvironmentInfo = TelemetryEnvironment())
    -> [String: AttributeValue] {
    var attributes: [String: AttributeValue] = [
      SemanticConventions.Service.name.rawValue: .string(options.googleAppID),
      SemanticConventions.Gcp.crashlyticsFirebaseAppId: .string(options.googleAppID),
    ]

    if let projectID = options.projectID, !projectID.isEmpty {
      attributes[SemanticConventions.Gcp.crashlyticsProjectId] = .string(projectID)
    }

    if let bundleIdentifier = environment.bundleIdentifier, !bundleIdentifier.isEmpty {
      attributes[SemanticConventions.Service.namespace.rawValue] = .string(bundleIdentifier)
    }

    if let appVersion = environment.appVersion, !appVersion.isEmpty {
      attributes[SemanticConventions.Service.version.rawValue] = .string(appVersion)
    }

    if let appBuildId = environment.appBuildId, !appBuildId.isEmpty {
      attributes[SemanticConventions.App.buildId.rawValue] = .string(appBuildId)
    }

    return attributes
  }

  /// Returns instrumentation scope attributes identifying the Crashlytics Telemetry client SDK.
  static func instrumentationScopeAttributes(
    environment: any TelemetryEnvironmentInfo = TelemetryEnvironment()
  ) -> [String: AttributeValue] {
    return [
      SemanticConventions.Gcp.crashlyticsClientArtifact: .string(
        FirebaseCrashlyticsTelemetry.scopeName
      ),
      SemanticConventions.Gcp.crashlyticsClientRepo: .string("firebase/firebase-ios-sdk"),
      SemanticConventions.Gcp.clientService.rawValue: .string("firebasetelemetry"),
      SemanticConventions.Gcp.crashlyticsClientVersion: .string("v\(environment.sdkVersion)"),
    ]
  }

  /// Returns the common attributes that should be attached to all telemetry signals.
  private static func commonAttributes() -> [String: AttributeValue] {
    var attributes: [String: AttributeValue] = [
      SemanticConventions.App.screenName.rawValue: .string(screenName.value()),
    ]

    if let sessionId = sessionId.value() {
      attributes[SemanticConventions.Session.id.rawValue] = .string(sessionId)
    }

    return attributes
  }

  /// Returns the common attributes that should be attached to all spans.
  static func commonSpanAttributes() -> [String: AttributeValue] {
    return commonAttributes()
  }

  /// Returns the common attributes that should be attached to all log records.
  static func commonLogAttributes() -> [String: AttributeValue] {
    return commonAttributes()
  }
}
