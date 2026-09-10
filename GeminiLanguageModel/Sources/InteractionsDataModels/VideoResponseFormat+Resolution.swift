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

extension VideoResponseFormat {
  /// The video output resolution. Defaults to 720p.
  package enum Resolution: Codable, Sendable, Equatable, Hashable {

    /// 360p resolution.
    case three60p

    /// 720p resolution.
    case seven20p

    /// 1080p resolution.
    case ten80p

    /// 4K resolution.
    case fourK

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension VideoResponseFormat.Resolution: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .three60p: "360p"
    case .seven20p: "720p"
    case .ten80p: "1080p"
    case .fourK: "4k"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "360p": self = .three60p
    case "720p": self = .seven20p
    case "1080p": self = .ten80p
    case "4k": self = .fourK
    default: self = .unrecognized(rawValue)
    }
  }
}
