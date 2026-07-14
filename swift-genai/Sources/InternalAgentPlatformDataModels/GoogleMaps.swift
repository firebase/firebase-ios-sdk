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


extension AgentPlatform {
  /// Tool to retrieve public maps data for grounding, powered by Google.
  public struct GoogleMaps: Codable, Sendable, Equatable, Hashable {
    /// Optional. Deprecated: The Google Maps contextual widget behavior in Grounding with Google Maps is being deprecated; this field is planned for removal and no longer has any effect once removed. If true, include the widget context token in the response.
    @available(*, deprecated)
    public var enableWidget: Bool?
    
    /// Creates a new `GoogleMaps`.
    public init(
      enableWidget: Bool? = nil
    ) {
      self.enableWidget = enableWidget
    }
    enum CodingKeys: String, CodingKey {
      case enableWidget = "enableWidget"
    }
  }
}