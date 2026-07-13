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
  /// Retrieval config.
  package struct RetrievalConfig: Codable, Sendable, Equatable, Hashable {
    /// The language code of the user.
    package var languageCode: String?
    
    /// The location of the user.
    package var latLng: GoogleTypeLatLng?
    
    /// Creates a new `RetrievalConfig`.
    package init(
      languageCode: String? = nil,
      latLng: GoogleTypeLatLng? = nil
    ) {
      self.languageCode = languageCode
      self.latLng = latLng
    }
    enum CodingKeys: String, CodingKey {
      case languageCode = "languageCode"
      case latLng = "latLng"
    }
  }
}