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
import OpenTelemetryApi

/// Instruments manual user interactions and emits corresponding OpenTelemetry log events.
final class UserInteractionInstrumentation {
  private let logger: Logger

  init(logger: Logger) {
    self.logger = logger
  }

  /// Records a user interaction event as an OpenTelemetry log record.
  ///
  /// - Parameter event: The user interaction event to record.
  func record(_ event: UserInteractionEvent) {
    logger
      .logRecordBuilder()
      .setEventName(event.eventName)
      .setSeverity(event.severity)
      .setAttributes(event.attributes)
      .emit()
  }
}
