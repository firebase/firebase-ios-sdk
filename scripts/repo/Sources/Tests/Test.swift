/*
 * Copyright 2025 Google LLC
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
import Logging
import Util

/// Command for running the integration tests of a given SDK.
public struct Test: ParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "test",
    abstract: "Run the integration tests for a given SDK.",
    usage: """
      test [--overwrite] [--secrets <file_path>] [--xcode <version_or_path>] [--platforms <platforms> ...] [--filter <suite_or_function> ...] [--exclude <suite_or_function> ...] [<sdk>]

      test --xcode Xcode_16.4.0 --platforms iOS --platforms macOS AI
      test --xcode "/Applications/Xcode_15.0.0.app" --platforms tvOS Storage
      test --overwrite --secrets ./scripts/secrets/AI.json AI
    """
  )

  @OptionGroup
  var options: CommonTestOptions

  @Option(
    help: """
    Optional test target(s) to run against. Repeat this option to filter by multiple targets.
    Can be a test suite or test function identifier (eg; "IntegrationTests-SPM/LiveSessionTests" or "IntegrationTests-SPM/LiveSessionTests/realtime_functionCalling").
    """
  )
  var filter: [String] = []

  @Option(
    help: """
    Optional test target(s) to exclude from running. Repeat this option to exclude multiple targets.
    Can be a test suite or test function identifier (eg; "IntegrationTests-SPM/LiveSessionTests" or "IntegrationTests-SPM/LiveSessionTests/realtime_functionCalling").
    """
  )
  var exclude: [String] = []

  static let log: Logger = .init(label: "Test")

  public init() {}

  public func validate() throws {
    // filter takes priority with xcodebuild, so we just don't allow them to be used in tandem
    // to avoid any edge case issues
    if !filter.isEmpty && !exclude.isEmpty {
      throw ValidationError(
        "Cannot supply both --filter and --exclude options, please only specify one."
      )
    }
  }

  private func buildExtraArguments() -> [String] {
    var arguments: [String] = []
    for item in filter {
      arguments.append(contentsOf: ["-only-testing", item])
      Self.log.info("Filtering tests", metadata: ["filter": "\(item)"])
    }
    for item in exclude {
      arguments.append(contentsOf: ["-skip-testing", item])
      Self.log.info("Excluding tests", metadata: ["exclude": "\(item)"])
    }

    return arguments
  }

  public func run() throws {
    let xcodePath = try options.resolveXcodePath(logger: Self.log)
    let extraArguments = buildExtraArguments()

    try options.withDecryptedSecrets(logger: Self.log) {
      try options.runBuildScript(
        method: "xcodebuild",
        actionDescription: "Running integration tests",
        xcodePath: xcodePath,
        extraArguments: extraArguments,
        logger: Self.log
      )
    }
  }
}
