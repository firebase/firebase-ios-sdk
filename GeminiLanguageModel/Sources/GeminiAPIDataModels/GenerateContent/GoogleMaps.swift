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

/// Tool to retrieve public maps data for grounding, powered by Google.
package struct GoogleMaps: Codable, Sendable, Equatable, Hashable, Buildable {
  /// Deprecated: The Google Maps contextual widget behavior in Grounding with Google Maps is being
  /// deprecated; this field is planned for removal and no longer has any effect once removed. If
  /// true, include the widget context token in the response.
  package var enableWidget: Bool?

  /// Specifies the types of Google Maps grounding to enable. Defaults to `places` when unset.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var groundingTypes: GoogleMapsGroundingTypes?

  /// Initializes a new `GoogleMaps`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case enableWidget
    case groundingTypes
  }
}
