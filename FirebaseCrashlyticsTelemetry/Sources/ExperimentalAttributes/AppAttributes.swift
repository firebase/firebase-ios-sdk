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

import OpenTelemetryApi

public extension SemanticConventions.App {
  /**
   This event represents a completed navigation to a destination of an application.

   - SeeAlso: [opentelemetry-android events.yaml](https://github.com/open-telemetry/opentelemetry-android/blob/main/semconv/model/android/events.yaml)
   - Note: Stability level is `development`.
   */
  static let navigationEvent = "app.navigation.complete"

  /**
   The destination name of the navigation event.

   - Examples:
   ```swift
   attributes[SemanticConventions.App.navigationDestination] = "ProductDetailScreen"
   attributes[SemanticConventions.App.navigationDestination] = "settings_route"
   ```
   - Requires: Value type should be `String`
   - Note: Required attribute for the `app.navigation.complete` event.
   - SeeAlso: [opentelemetry-android events.yaml](https://github.com/open-telemetry/opentelemetry-android/blob/main/semconv/model/android/events.yaml)
   */
  static let navigationDestination = "app.navigation.destination.name"
}
