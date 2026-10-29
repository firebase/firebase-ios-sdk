/*
 * Copyright 2026 Google LLC
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

// What the tool tells the user besides its results: errors, warnings, and how long things took.
// Logging itself is in Logging.swift.

/// An error with a message for the user.
struct ZipBuilderError: Error, CustomStringConvertible {
  var description: String
  init(_ description: String) {
    self.description = description
  }
}

/// Logs a warning from the caller's location, or collects it while `Warnings.collected` is set
/// (tests).
func warn(_ message: String, file: String = #fileID, function: String = #function,
          line: UInt = #line) {
  if let collected = Warnings.collected {
    collected.append(message)
  } else {
    logger.warning("\(message)", file: file, function: function, line: line)
  }
}

/// Warnings collected instead of printed, so tests can check them.
final class Warnings: @unchecked Sendable {
  /// Set by tests with `Warnings.$collected.withValue(…)`; warnings go here instead of stderr.
  @TaskLocal static var collected: Warnings?

  private let lock = NSLock()
  private var messages: [String] = []

  var all: [String] {
    lock.withLock { messages }
  }

  func append(_ message: String) {
    lock.withLock { messages.append(message) }
  }
}

/// `duration` for people, in minutes and seconds, e.g. `4m 13s` or `16s`.
func formatted(_ duration: Duration) -> String {
  duration.formatted(.units(allowed: [.minutes, .seconds], width: .narrow))
}

/// The size of the file at `path` for people, e.g. `1.2 MB`. A file that can't be read counts as
/// empty: the size is only logged.
func formattedSize(ofFile path: Path) -> String {
  let attributes = try? FileManager.default.attributesOfItem(atPath: path)
  let size = attributes?[.size] as? Int ?? 0
  return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
}
