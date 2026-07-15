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

extension GeminiDataModels.GenerationConfig {
  /// Optional. If specified, the media resolution specified will be used.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Optional. If specified, the media resolution specified will be used.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Optional. The token resolution at which input media content is sampled. This is
  /// used to control the trade-off between the quality of the response and the
  /// number of tokens used to represent the media. A higher resolution allows
  /// the model to perceive more detail, which can lead to a more nuanced
  /// response, but it will also use more tokens. This does not affect the
  /// image dimensions sent to the model.
  package enum MediaResolution: Codable, Sendable, Equatable, Hashable {
    /// Media resolution set to low (64 tokens).
    case low
    
    /// Media resolution set to medium (256 tokens).
    case medium
    
    /// Media resolution set to high (zoomed reframing with 256 tokens).
    case high
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension GeminiDataModels.GenerationConfig.MediaResolution: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .low: "MEDIA_RESOLUTION_LOW"
    case .medium: "MEDIA_RESOLUTION_MEDIUM"
    case .high: "MEDIA_RESOLUTION_HIGH"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "MEDIA_RESOLUTION_LOW": self = .low
    case "MEDIA_RESOLUTION_MEDIUM": self = .medium
    case "MEDIA_RESOLUTION_HIGH": self = .high
    default: self = .unrecognized(rawValue)
    }
  }
}