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

import GeminiAPIDataModels

extension Content {
  /// Returns a `Content` containing a single text part.
  ///
  /// - Parameters:
  ///   - text: The text of the part.
  ///   - role: The producer of the content, such as `"user"` or `"model"`.
  /// - Returns: A `Content` with one text `Part`.
  static func text(_ text: String, role: String? = nil) -> Content {
    Content {
      $0.parts = [Part { $0.data = .text(text) }]
      $0.role = role
    }
  }
}
