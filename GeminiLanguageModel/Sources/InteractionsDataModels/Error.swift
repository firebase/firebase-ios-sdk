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

/// Error message from an interaction.
package struct Error: Codable, Sendable, Equatable, Hashable {

  /// A URI that identifies the error type.
  package let code: String?

  /// A human-readable error message.
  package let message: String?

  /// Creates a new `Error`.
  ///
  /// - Parameters:
  ///   - code: A URI that identifies the error type.
  ///   - message: A human-readable error message.
  package init(
    code: String? = nil,
    message: String? = nil
  ) {
    self.code = code
    self.message = message
  }
  enum CodingKeys: String, CodingKey {
    case code = "code"
    case message = "message"
  }
}
