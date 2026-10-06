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
  /// The default maximum length of a single line, in bytes (100 MiB).
  ///
  /// The backend limits request payloads to 100 MB, so inline generated content (e.g., base64
  /// encoded images) is expected to fit comfortably within this limit.
  package static let defaultMaxLineLength = 100 * 1024 * 1024

  /// The largest stitched-line buffer, in bytes, whose capacity is retained for reuse (64 KiB).
  private static let retainedBufferCapacity = 64 * 1024

  /// The maximum length of a single line, in bytes, excluding line delimiters.
  package let maxLineLength: Int

  private var buffer = Data()
  private var pendingCR = false

  /// Initializes a new line decoder with an empty buffer.
  ///
  /// - Parameter maxLineLength: The maximum length of a single line, in bytes, excluding line
  ///   delimiters; defaults to ``defaultMaxLineLength``.
  package init(maxLineLength: Int = HTTPLineDecoder.defaultMaxLineLength) {
    self.maxLineLength = maxLineLength
  }

  /// Feeds a new chunk of data and returns all complete lines found.
  ///
  /// - Parameter data: The incoming data chunk.
  /// - Returns: An array of decoded lines with trailing line delimiters stripped.
  /// - Throws: `URLError(.dataLengthExceedsMaximum)` if a line exceeds ``maxLineLength``.
  package mutating func feed(_ data: Data) throws -> [String] {
    guard !data.isEmpty else { return [] }

    var lines: [String] = []
    var searchStartIndex = data.startIndex

    while searchStartIndex < data.endIndex {
      // Uses a single `firstIndex(where:)` to avoid an O(N^2) performance edge-case.
      // Two separate `firstIndex(of:)` scans would repeatedly scan the entire remainder
      // of the chunk if one delimiter type (e.g. CR) is missing from the payload.
      guard
        let nextNewlineIndex = data[searchStartIndex...].firstIndex(where: {
          // LF (\n) or CR (\r)
          $0 == 0x0A || $0 == 0x0D
        })
      else {
        let remainder = data[searchStartIndex...]
        try checkLineLength(remainder.count)
        buffer.append(remainder)
        pendingCR = false
        break
      }

      let byte = data[nextNewlineIndex]

      if pendingCR {
        pendingCR = false
        // Skip the LF (\n) half of a CRLF (\r\n) pair
        if byte == 0x0A && nextNewlineIndex == searchStartIndex {
          searchStartIndex = data.index(after: nextNewlineIndex)
          continue
        }
      }

      let lineSlice = data[searchStartIndex..<nextNewlineIndex]
      try checkLineLength(lineSlice.count)
      let line: String

      if buffer.isEmpty {
        // Fast path: Decode directly from the slice without copying into the accumulation buffer
        line = String(decoding: lineSlice, as: UTF8.self)
      } else {
        // Slow path: Stitch together bytes split across chunk boundaries
        buffer.append(lineSlice)
        line = String(decoding: buffer, as: UTF8.self)
        // Keep the allocation for typical line sizes to avoid reallocating on every stitched line,
        // but release it after an unusually large line (e.g., inline image data) so the capacity
        // is not retained for the remainder of the stream.
        buffer.removeAll(keepingCapacity: buffer.count <= Self.retainedBufferCapacity)
      }
      lines.append(line)

      // Track CR (\r) in case the next byte is LF (\n)
      pendingCR = (byte == 0x0D)

      searchStartIndex = data.index(after: nextNewlineIndex)
    }

    return lines
  }

  /// Throws if appending `additionalByteCount` bytes to the buffered partial line would exceed
  /// ``maxLineLength``, releasing the buffered bytes before throwing.
  private mutating func checkLineLength(_ additionalByteCount: Int) throws {
    guard buffer.count + additionalByteCount > maxLineLength else { return }
    buffer.removeAll(keepingCapacity: false)
    pendingCR = false
    throw URLError(
      .dataLengthExceedsMaximum,
      userInfo: [
        NSLocalizedDescriptionKey: "Response line exceeded the maximum of \(maxLineLength) bytes."
      ]
    )
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
