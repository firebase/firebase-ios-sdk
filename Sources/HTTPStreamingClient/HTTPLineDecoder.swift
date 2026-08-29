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

package import Foundation

/// An incremental decoder that extracts UTF-8 lines of text from streaming byte chunks.
package struct HTTPLineDecoder: Sendable {
  private var buffer = Data()
  private var pendingCR = false

  /// Initializes a new line decoder with an empty buffer.
  package init() {}

  /// Feeds a new chunk of data and returns all complete lines found.
  ///
  /// - Parameter data: The incoming data chunk.
  /// - Returns: An array of decoded lines with trailing line delimiters stripped.
  package mutating func feed(_ data: Data) -> [String] {
    guard !data.isEmpty else { return [] }

    var lines: [String] = []
    var searchStartIndex = data.startIndex

    if pendingCR {
      pendingCR = false
      if data[searchStartIndex] == 0x0A {
        searchStartIndex = data.index(after: searchStartIndex)
      }
    }

    while searchStartIndex < data.endIndex {
      guard
        let nextNewlineIndex = data[searchStartIndex...].firstIndex(where: {
          $0 == 0x0A || $0 == 0x0D
        })
      else {
        buffer.append(data[searchStartIndex...])
        pendingCR = false
        break
      }

      let byte = data[nextNewlineIndex]

      if pendingCR {
        pendingCR = false
        if byte == 0x0A && nextNewlineIndex == searchStartIndex {
          searchStartIndex = data.index(after: nextNewlineIndex)
          continue
        }
      }

      let lineSlice = data[searchStartIndex..<nextNewlineIndex]
      let line: String

      if buffer.isEmpty {
        // Fast path: Zero-copy direct slice decoding
        line = String(decoding: lineSlice, as: UTF8.self)
      } else {
        // Slow path: Stitch together bytes split across chunk boundaries
        buffer.append(lineSlice)
        line = String(decoding: buffer, as: UTF8.self)
        buffer.removeAll(keepingCapacity: true)
      }
      lines.append(line)

      if byte == 0x0D {
        pendingCR = true
      } else {
        pendingCR = false
      }

      searchStartIndex = data.index(after: nextNewlineIndex)
    }

    return lines
  }

  /// Flushes any remaining bytes in the buffer as the final line.
  ///
  /// - Returns: The final line if the buffer is non-empty, or `nil`.
  package mutating func flush() -> String? {
    pendingCR = false
    guard !buffer.isEmpty else { return nil }
    let line = String(decoding: buffer, as: UTF8.self)
    buffer.removeAll(keepingCapacity: false)
    return line
  }
}
