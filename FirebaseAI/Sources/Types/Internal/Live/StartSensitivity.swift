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

/// Start of speech sensitivity.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct StartSensitivity: EncodableProtoEnum, Hashable, Sendable {
  enum Kind: String {
    case high = "START_SENSITIVITY_HIGH"
    case low = "START_SENSITIVITY_LOW"
  }

  /// Automatic detection will detect the start of speech more often.
  public static let high = StartSensitivity(kind: .high)

  /// Automatic detection will detect the start of speech less often.
  public static let low = StartSensitivity(kind: .low)

  /// Returns the raw string representation of the `StartSensitivity` value.
  public let rawValue: String
}
