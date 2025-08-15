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

/// Options about which input is included in the user's turn.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct TurnCoverage: EncodableProtoEnum, Hashable, Sendable {
  enum Kind: String {
    case onlyActivity = "TURN_INCLUDES_ONLY_ACTIVITY"
    case allInput = "TURN_INCLUDES_ALL_INPUT"
  }

  /// The users turn only includes activity since the last turn, excluding
  /// inactivity (e.g. silence on the audio stream).
  public static let onlyActivity = TurnCoverage(kind: .onlyActivity)

  /// The users turn includes all realtime input since the last turn, including
  /// inactivity (e.g. silence on the audio stream). This is the default
  // behavior.
  public static let allInput = TurnCoverage(kind: .allInput)

  /// Returns the raw string representation of the `TurnCoverage` value.
  public let rawValue: String
}
