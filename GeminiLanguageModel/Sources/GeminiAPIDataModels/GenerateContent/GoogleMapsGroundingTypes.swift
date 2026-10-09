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

/// Defines the types of Google Maps grounding that can be enabled and their configurations.
///
/// > Important: This type is not supported in the Gemini Developer API.
package struct GoogleMapsGroundingTypes: Codable, Sendable, Equatable, Hashable, Buildable {
  /// Enables grounding with Google Maps Places. This is the default grounding type when no
  /// `GroundingTypes` are specified.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var places: GoogleMapsPlaces?

  /// Enables grounding with Google Maps Routing APIs (ComputeRoutes and SearchAlongRoute).
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var routing: GoogleMapsRouting?

  /// Initializes a new `GoogleMapsGroundingTypes`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case places
    case routing
  }
}
