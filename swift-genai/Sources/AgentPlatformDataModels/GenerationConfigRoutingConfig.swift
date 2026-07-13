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
  /// The configuration for routing the request to a specific model. This can be used to control which model is used for the generation, either automatically or by specifying a model name.
  package struct GenerationConfigRoutingConfig: Codable, Sendable, Equatable, Hashable {
    /// In this mode, the model is selected automatically based on the content of the request.
    package var autoMode: GenerationConfigRoutingConfigAutoRoutingMode?
    
    /// In this mode, the model is specified manually.
    package var manualMode: GenerationConfigRoutingConfigManualRoutingMode?
    
    /// Creates a new `GenerationConfigRoutingConfig`.
    package init(
      autoMode: GenerationConfigRoutingConfigAutoRoutingMode? = nil,
      manualMode: GenerationConfigRoutingConfigManualRoutingMode? = nil
    ) {
      self.autoMode = autoMode
      self.manualMode = manualMode
    }
    enum CodingKeys: String, CodingKey {
      case autoMode = "autoMode"
      case manualMode = "manualMode"
    }
  }
}