/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import FirebaseFirestore
import FirebaseSharedSwift

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
private var _iso8601Formatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = .withInternetDateTime
  return formatter
}()

extension StructureDecoder.DateDecodingStrategy {
  public static func timestamp(fallback: StructureDecoder
    .DateDecodingStrategy = .deferredToDate) -> StructureDecoder.DateDecodingStrategy {
    return .custom { decoder in
      let container = try decoder.singleValueContainer()
      do {
        let value = try container.decode(Timestamp.self)
        return value.dateValue()
      } catch {
        switch fallback {
        case .deferredToDate:
          return try Date(from: decoder)

        case .secondsSince1970:
          let double = try container.decode(Double.self)
          return Date(timeIntervalSince1970: double)

        case .millisecondsSince1970:
          let double = try container.decode(Double.self)
          return Date(timeIntervalSince1970: double / 1000.0)

        case .iso8601:
          if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
            let string = try container.decode(String.self)
            guard let date = _iso8601Formatter.date(from: string) else {
              throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected date string to be ISO8601-formatted."
              ))
            }

            return date
          } else {
            fatalError("ISO8601DateFormatter is unavailable on this platform.")
          }

        case let .formatted(formatter):
          let string = try container.decode(String.self)
          guard let date = formatter.date(from: string) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
              codingPath: decoder.codingPath,
              debugDescription: "Date string does not match format expected by formatter."
            ))
          }

          return date

        case let .custom(closure):
          return try closure(decoder)
        }
      }
    }
  }
}
