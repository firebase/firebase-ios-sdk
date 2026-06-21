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

/// Utilities to simplify String operations.
public extension String {
  /// Finds and returns the ranges of all occurrences of a given string within a given range of the
  /// String, subject to given options,
  /// using the specified locale, if any.
  /// - Returns: An an optional array of ranges where each range corresponds to an occurrence of the
  /// substring in the given string.
  func ranges<T: StringProtocol>(of substring: T, options: CompareOptions = .literal,
                                 locale: Locale? = nil) -> [Range<Index>] {
    var ranges: [Range<Index>] = []

    let end = endIndex
    var searchRange = startIndex ..< end

    while searchRange.lowerBound < end {
      guard let range = range(
        of: substring,
        options: options,
        range: searchRange,
        locale: locale
      )
      else { break }

      ranges.append(range)

      let shiftedStart = index(range.lowerBound, offsetBy: 1)
      searchRange = shiftedStart ..< end
    }

    return ranges
  }
}
