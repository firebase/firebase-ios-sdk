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

extension AgentPlatform.ImageResponseFormat {
  /// Optional. The size of the image output.
  package enum ImageSize: Codable, Sendable, Equatable, Hashable {
    /// 512px image size.
    case fiveTwelve
    
    /// 1K image size.
    case oneK
    
    /// 2K image size.
    case twoK
    
    /// 4K image size.
    case fourK
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.ImageResponseFormat.ImageSize: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .fiveTwelve: "IMAGE_SIZE_FIVE_TWELVE"
    case .oneK: "IMAGE_SIZE_ONE_K"
    case .twoK: "IMAGE_SIZE_TWO_K"
    case .fourK: "IMAGE_SIZE_FOUR_K"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "IMAGE_SIZE_FIVE_TWELVE": self = .fiveTwelve
    case "IMAGE_SIZE_ONE_K": self = .oneK
    case "IMAGE_SIZE_TWO_K": self = .twoK
    case "IMAGE_SIZE_FOUR_K": self = .fourK
    default: self = .unrecognized(rawValue)
    }
  }
}