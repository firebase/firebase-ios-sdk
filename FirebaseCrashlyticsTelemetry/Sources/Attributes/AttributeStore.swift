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
    var attributes = commonAttributes()
    // TODO: Remove this attribute. Currently added as a work around to a limitation in the
    // backend server.
    attributes["gcp.firebase.app_version"] = .string("1.0")

    if let threadId = currentThreadId() {
      attributes[SemanticConventions.Thread.id.rawValue] = .int(threadId)
    }

    if let threadName = currentThreadName() {
      attributes[SemanticConventions.Thread.name.rawValue] = .string(threadName)
    }

    return attributes
  }

  /// Returns the common attributes that should be attached to all log records.
  static func commonLogAttributes() -> [String: AttributeValue] {
    return commonAttributes()
  }

  private static func currentThreadId() -> Int? {
    var threadId: UInt64 = 0
    guard pthread_threadid_np(nil, &threadId) == 0 else {
      return nil
    }
    return Int(clamping: threadId)
  }

  private static func currentThreadName() -> String? {
    if Thread.isMainThread {
      return "main"
    }

    if let name = Thread.current.name, !name.isEmpty {
      return name
    }

    var buffer = [CChar](repeating: 0, count: 64)
    if pthread_getname_np(pthread_self(), &buffer, buffer.count) == 0 {
      let name = String(cString: buffer)
      if !name.isEmpty {
        return name
      }
    }

    return nil
  }
}
