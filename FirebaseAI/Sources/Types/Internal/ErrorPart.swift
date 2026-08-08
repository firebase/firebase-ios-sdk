// Copyright 2024 Google LLC
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

struct ErrorPart: Part, Error {
  let error: Error

  let isThought = false
  let thoughtSignature: String? = nil

  init(_ error: Error) {
    self.error = error
  }
}

// MARK: - Codable Conformances

extension ErrorPart: Codable {
  init(from decoder: any Decoder) throws {
    fatalError("Decoding an ErrorPart is not supported.")
  }

  func encode(to encoder: any Encoder) throws {
    fatalError("Encoding an ErrorPart is not supported.")
  }
}

// MARK: - Equatable Conformances

extension ErrorPart: Equatable {
  static func == (lhs: ErrorPart, rhs: ErrorPart) -> Bool {
    fatalError("Comparing ErrorParts for equality is not supported.")
  }
}
