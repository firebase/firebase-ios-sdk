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

extension AgentPlatform.ModalityTokenCount {
  /// The modality that this token count applies to.
  package enum Modality: Codable, Sendable, Equatable, Hashable {
    /// The `Part` contains plain text.
    case text
    
    /// The `Part` contains an image.
    case image
    
    /// The `Part` contains a video.
    case video
    
    /// The `Part` contains audio.
    case audio
    
    /// The `Part` contains a document, such as a PDF.
    case document
    
    /// Unrecognized case.
    ///
    /// - Parameter value: The raw string value of the unrecognized enum case.
    case unrecognized(_ value: String)
  }
}

// MARK: - RawRepresentable Conformance

extension AgentPlatform.ModalityTokenCount.Modality: RawRepresentable {
  package var rawValue: String {
    switch self {
    case .text: "TEXT"
    case .image: "IMAGE"
    case .video: "VIDEO"
    case .audio: "AUDIO"
    case .document: "DOCUMENT"
    case .unrecognized(let value): value
    }
  }

  package init(rawValue: String) {
    switch rawValue {
    case "TEXT": self = .text
    case "IMAGE": self = .image
    case "VIDEO": self = .video
    case "AUDIO": self = .audio
    case "DOCUMENT": self = .document
    default: self = .unrecognized(rawValue)
    }
  }
}