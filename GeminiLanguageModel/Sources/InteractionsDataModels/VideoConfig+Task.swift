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

extension VideoConfig {
  /// Optional task mode for video generation. If not specified, the model
  /// automatically determines the appropriate mode based on the provided text
  /// prompt and input media.
  package enum Task: Codable, Sendable, Equatable, Hashable {

    /// Generates video solely from a text prompt.
    case textToVideo

    /// Generates video from one or two source images. The first image defines
    /// the starting frame, and the optional second image defines the ending
    /// frame.
    case imageToVideo

    /// Generates video using reference media (such as images, audio, or video).
    case referenceToVideo

    /// Modifies an existing input video.
    case edit

    /// Extends an existing input video.
    case extend

    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension VideoConfig.Task: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .textToVideo: "text_to_video"
    case .imageToVideo: "image_to_video"
    case .referenceToVideo: "reference_to_video"
    case .edit: "edit"
    case .extend: "extend"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "text_to_video": self = .textToVideo
    case "image_to_video": self = .imageToVideo
    case "reference_to_video": self = .referenceToVideo
    case "edit": self = .edit
    case "extend": self = .extend
    default: self = .unrecognized(rawValue)
    }
  }
}
