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
import OpenTelemetryApi

/// Provides common OpenTelemetry attributes to be attached across telemetry signals.
enum AttributeStore {
  // TODO: Add resource attributes.
  // TODO: Add instrumentation scope attributes.

  private static let screenName = UnfairLock<String>(CrashlyticsView.unknown.name)

  /// Updates the currently active screen name.
  static func setScreenName(_ name: String) {
    screenName.withLock { $0 = name }
  }

  /// Returns the common attributes that should be attached to all spans.
  static func commonSpanAttributes() -> [String: AttributeValue] {
    return [
      SemanticConventions.App.screenName.rawValue: .string(screenName.value()),
      // TODO: Remove this attribute. Currently added as a work around to a limitation in the
      // backend server.
      "gcp.firebase.app_version": .string("1.0"),
    ]
  }

  /// Returns the common attributes that should be attached to all log records.
  static func commonLogAttributes() -> [String: AttributeValue] {
    return [
      SemanticConventions.App.screenName.rawValue: .string(screenName.value()),
    ]
  }
}
