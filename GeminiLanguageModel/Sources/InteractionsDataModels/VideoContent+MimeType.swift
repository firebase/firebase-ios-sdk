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

extension VideoContent {
  /// The mime type of the video.
  package enum MimeType: Codable, Sendable, Equatable, Hashable {

    /// MP4 video format
    case mp4

    /// MPEG video format
    case mpeg

    /// MPG video format
    case mpg

    /// MOV video format
    case mov

    /// AVI video format
    case avi

    /// FLV video format
    case xFlv

    /// WebM video format
    case webm

    /// WMV video format
    case wmv

    /// 3GPP video format
    case threeGpp

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension VideoContent.MimeType: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .mp4: "video/mp4"
    case .mpeg: "video/mpeg"
    case .mpg: "video/mpg"
    case .mov: "video/mov"
    case .avi: "video/avi"
    case .xFlv: "video/x-flv"
    case .webm: "video/webm"
    case .wmv: "video/wmv"
    case .threeGpp: "video/3gpp"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "video/mp4": self = .mp4
    case "video/mpeg": self = .mpeg
    case "video/mpg": self = .mpg
    case "video/mov": self = .mov
    case "video/avi": self = .avi
    case "video/x-flv": self = .xFlv
    case "video/webm": self = .webm
    case "video/wmv": self = .wmv
    case "video/3gpp": self = .threeGpp
    default: self = .unrecognized(rawValue)
    }
  }
}
