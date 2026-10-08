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

/// Represents a manual user interaction event to be recorded as an OpenTelemetry event.
enum UserInteractionEvent: Equatable, Sendable {
  case tap(widgetId: String)

  /// The OpenTelemetry semantic event name for this interaction.
  var eventName: String {
    switch self {
    case .tap:
      return SemanticConventions.App.widgetClickEvent
    }
  }

  /// The OpenTelemetry severity level for this interaction event.
  var severity: Severity {
    return .info
  }

  /// The OpenTelemetry semantic attributes for this interaction event.
  var attributes: [String: AttributeValue] {
    switch self {
    case let .tap(widgetId):
      return [
        SemanticConventions.App.widgetId.rawValue: .string(widgetId),
      ]
    }
  }
}
