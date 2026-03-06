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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct GenerateObjectResponse<T: Decodable> {
  public let response: GenerateContentResponse

  init(response: GenerateContentResponse) {
    self.response = response
  }

  public func getObject(candidateIndex: Int = 0) throws -> T? {
    guard response.candidates.indices.contains(candidateIndex) else {
      return nil
    }

    let candidate = response.candidates[candidateIndex]
    let parts = candidate.content.parts.filter { !$0.isThought }
    let textParts = parts.compactMap { $0 as? TextPart }
    let json = textParts.map { $0.text }.joined()
    guard !json.isEmpty else {
      return nil
    }
    do {
      guard let jsonData = json.data(using: .utf8) else {
        throw DecodingError.dataCorrupted(
          .init(codingPath: [], debugDescription: "Failed to convert JSON to UTF8 Data: \(json)")
        )
      }

      return try JSONDecoder().decode(T.self, from: jsonData)
    } catch {
      throw GenerateContentError.internalError(underlying: error)
    }
  }
}
