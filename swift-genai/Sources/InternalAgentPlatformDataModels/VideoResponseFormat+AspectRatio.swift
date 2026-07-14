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

extension AgentPlatform.VideoResponseFormat {
  /// The aspect ratio for the video output.
  public enum AspectRatio: Codable, Sendable, Equatable, Hashable {
    /// 16:9 aspect ratio.
    case sixteenByNine
    
    /// 9:16 aspect ratio.
    case nineBySixteen
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.VideoResponseFormat.AspectRatio: RawRepresentable {
  public var rawValue: String {
    switch self {
    case .sixteenByNine: "ASPECT_RATIO_SIXTEEN_BY_NINE"
    case .nineBySixteen: "ASPECT_RATIO_NINE_BY_SIXTEEN"
    case .unrecognized(let value): value
    }
  }

  public init(rawValue: String) {
    switch rawValue {
    case "ASPECT_RATIO_SIXTEEN_BY_NINE": self = .sixteenByNine
    case "ASPECT_RATIO_NINE_BY_SIXTEEN": self = .nineBySixteen
    default: self = .unrecognized(rawValue)
    }
  }
}