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

/// The different ways of handling user activity.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ActivityHandling: EncodableProtoEnum, Hashable, Sendable {
  enum Kind: String {
    case interrupts = "START_OF_ACTIVITY_INTERRUPTS"
    case noInterrupt = "NO_INTERRUPTION"
  }

  /// If true, start of activity will interrupt the model's response (also
  /// called "barge in"). The model's current response will be cut-off in the
  /// moment of the interruption. This is the default behavior.
  public static let interrupts = ActivityHandling(kind: .interrupts)

  /// The model's response will not be interrupted.
  public static let noInterrupt = ActivityHandling(kind: .noInterrupt)

  /// Returns the raw string representation of the `ActivityHandling` value.
  public let rawValue: String
}
