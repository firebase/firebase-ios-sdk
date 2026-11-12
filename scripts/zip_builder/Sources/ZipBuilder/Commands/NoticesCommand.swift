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

import ArgumentParser
import Foundation

/// Writes the license notices file on its own, so a release can check it in and copy it with
/// `zip.files` (`zip.notices.atBuildTime: false`) instead of generating it in `makeZip`.
struct NoticesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "notices",
    abstract: "Write the license notices file (zip.notices) for what the release ships."
  )

  @OptionGroup var options: SharedOptions
  @OptionGroup var logging: LoggingOptions

  @Option(help: "Use this plan instead of planning again.")
  var plan: String?

  @Option(help: "Write the notices to this file instead of standard output.")
  var output: String?

  func run() async throws {
    logging.apply()
    let config = try options.loadConfig()
    // Checked before planning, which takes a while.
    guard let noticesConfig = config.zip.notices else {
      throw ZipBuilderError(
        "No zip.notices in \(options.configPath): add it to generate the license notices."
      )
    }
    let plan = try await options.loadOrMakePlan(plan, config)
    // `atBuildTime` only decides whether `makeZip` writes the file; this command always does,
    // with the same text.
    let (text, entryCount) = try notices(plan, noticesConfig, packageRoot: options.packagePath)
    let entries = entryCount == 1 ? "1 entry" : "\(entryCount) entries"
    guard let output else {
      // Standard output carries only the result, byte for byte as `--output` would write it.
      print(text, terminator: "")
      logger.info("Wrote the license notices (\(entries)) to standard output")
      return
    }
    do {
      try Data(text.utf8).write(to: URL(fileURLWithPath: output), options: .atomic)
    } catch {
      throw ZipBuilderError("Couldn't write the notices to \(output): "
        + error.localizedDescription)
    }
    logger.info("Wrote the license notices (\(entries)) to \(output)")
  }
}
