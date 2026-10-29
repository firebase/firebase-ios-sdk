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

struct VerifyCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "verify",
    abstract: "Check that a distribution links, imports, and is complete."
  )

  @OptionGroup var logging: LoggingOptions

  @Argument(help: "A distribution folder or zip.")
  var distribution: String

  @Option(help: ArgumentHelp("The config, for products.base and verify.skipImports.",
                             discussion: "Default: ./zip_builder.jsonc, else ./zip_builder.json, if either exists."))
  var config: String?

  @Flag(help: "Fail on unsigned .xcframeworks instead of skipping them.")
  var requireSignatures = false

  @Option(help: ArgumentHelp(
    "A directory of .xcframeworks the distribution needs but doesn't ship, e.g. "
      + "<work-dir>/xcframeworks.",
    discussion: "For a distribution built without its dependencies: they're linked with every "
      + "folder and searched for imports, but not checked themselves.",
    valueName: "dir"
  ))
  var dependencies: String?

  /// The config, if one exists. A missing `--config` file is an error; a missing default isn't.
  func loadConfig() throws -> Config? {
    try Config.load(from: config, orDefaultIn: ".")
  }

  func run() async throws {
    logging.apply()
    let config = try loadConfig()
    let contents = try await readDistribution(at: distribution)
    defer { contents.removeExtracted() }
    var needed: [XCFramework] = []
    if let dependencies {
      needed = try await readXCFrameworks(in: dependencies)
    }
    guard try await verifyAndReport(contents, at: distribution, config: config,
                                    requireSignatures: requireSignatures,
                                    dependencies: needed) else {
      throw ExitCode.failure
    }
  }
}

/// Verifies `distribution` with the config's base folder and skip list, prints the report for
/// `path`, and returns whether every check passed. `dependencies` are `.xcframework`s it needs but
/// doesn't ship (see `verify`). Shared by `verify` and `release`.
func verifyAndReport(_ distribution: Distribution, at path: Path, config: Config?,
                     requireSignatures: Bool,
                     dependencies: [XCFramework] = []) async throws -> Bool {
  let checks = try await verify(distribution, baseFolder: config?.products.base?.product,
                                skippedImports: Set(config?.verify.skipImports ?? []),
                                requireSignatures: requireSignatures,
                                dependencies: dependencies)
  print(renderVerification(checks, of: path))
  return !checks.contains(where: \.failed)
}
