// Copyright 2025 Google LLC
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

/// Represents the available response modalities.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ResponseModality: EncodableProtoEnum, Sendable {
  enum Kind: String {
    case text = "TEXT"
    case image = "IMAGE"
    case audio = "AUDIO"
  }

  /// Text response modality.
  public static let text = ResponseModality(kind: .text)

  /// Image response modality.
  public static let image = ResponseModality(kind: .image)

  /// Audio response modality.
  public static let audio = ResponseModality(kind: .audio)

  let rawValue: String
}
