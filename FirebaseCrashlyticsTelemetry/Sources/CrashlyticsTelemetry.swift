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
internal import FirebaseCore
internal import FirebaseCoreExtension

public final class CrashlyticsTelemetry {
  private init() {}

  // MARK: - Public API for testing

  // TODO: Remove all the testing API.

  /// Starts a new telemetry span chronologically linked to active traces.
  ///
  /// - Returns: The total count of currently active spans, or `0` if the SDK is unconfigured.
  @discardableResult
  public static func startSpan() -> Int {
    return FirebaseCrashlyticsTelemetry.instance?.startSpan() ?? 0
  }

  /// Increments custom tracking attributes inside active spans for debugging and correlation.
  ///
  /// - Returns: The updated attribute counter value, or `0` if the SDK is unconfigured.
  @discardableResult
  public static func incrementCustomAttribute() -> Int {
    return FirebaseCrashlyticsTelemetry.instance?.incrementCustomAttribute() ?? 0
  }

  /// Completes the most recently started active span, marking its status as OK and ending its
  /// lifecycle.
  ///
  /// - Returns: The remaining count of active spans, or `0` if the SDK is unconfigured.
  @discardableResult
  public static func stopSpan() -> Int {
    return FirebaseCrashlyticsTelemetry.instance?.stopSpan() ?? 0
  }

  /// Emits a diagnostic telemetry log, associating it with the current span context if one exists.
  public static func addLog() {
    FirebaseCrashlyticsTelemetry.instance?.addLog()
  }
}
