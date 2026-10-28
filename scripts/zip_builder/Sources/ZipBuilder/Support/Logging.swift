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
import Logging
import Synchronization

/// The tool's logger. Progress and warnings go to standard error, so standard output only carries a
/// command's results (e.g. `diff`'s report). `--quiet` and `--verbose` set `minimumLogLevel`.
let logger = Logger(label: "zip-builder") { ZipBuilderLogHandler(label: $0) }

/// The least severe level that's logged: `.info` until `LoggingOptions.apply()` sets it from
/// `--quiet` or `--verbose` (`--verbose` also logs every command the tool runs).
let minimumLogLevel = Mutex(Logger.Level.info)

/// `StreamLogHandler`'s format, on standard error, with the call site in place of the module:
/// `2026-10-22T13:10:47-0500 info zip-builder: [ZipBuilder/BuildXCFrameworks.swift:173] Archiving
/// ios`.
struct ZipBuilderLogHandler: LogHandler {
  let label: String
  var metadata: Logger.Metadata = [:]
  /// Where finished lines go; standard error unless a test captures them.
  var write: @Sendable (String) -> Void = { FileHandle.standardError.write(Data($0.utf8)) }

  /// `LogHandler` requires a settable level. This one reads and writes the process-wide
  /// `minimumLogLevel`, so `--quiet` and `--verbose` reach every handler, not just one copy.
  var logLevel: Logger.Level {
    get { minimumLogLevel.withLock { $0 } }
    set { minimumLogLevel.withLock { $0 = newValue } }
  }

  subscript(metadataKey key: String) -> Logger.Metadata.Value? {
    get { metadata[key] }
    set { metadata[key] = newValue }
  }

  func log(event: LogEvent) {
    let metadata = metadata.merging(event.metadata ?? [:]) { $1 }
    let metadataText = metadata.sorted { $0.key < $1.key }.map { " \($0.key)=\($0.value)" }
      .joined()
    let location = "[\(event.file):\(event.line)]"
    write("\(timestamp()) \(event.level) \(label):\(metadataText) \(location) \(event.message)\n")
  }

  /// The local time, e.g. `2026-10-22T13:10:47-0500`, as `StreamLogHandler` writes it.
  private func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    return formatter.string(from: Date())
  }
}
