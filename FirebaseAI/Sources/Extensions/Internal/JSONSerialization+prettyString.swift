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

extension JSONSerialization {
  /// Converts a `Data` instance of a JSON object into a decoded and formatted string.
  ///
  /// - Parameters:
  ///   - with: The JSON object to decode.
  /// - Returns:
  ///   A formatted string representing the provided data, or `nil` if the data is
  ///   not a valid JSON object.
  static func prettyString(with data: Data) -> String? {
    guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
          let prettyPrintData = try? JSONSerialization.data(
            withJSONObject: jsonObject,
            options: .prettyPrinted
          ) else {
      return nil
    }
    return String(data: prettyPrintData, encoding: .utf8)
  }
}
