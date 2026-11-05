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
import Common
import Foundation
import Logging
import ManifestReader

/// Root entry point for the `zip-builder` command-line utility.
@main
public struct ZipBuilder: AsyncParsableCommand {
  /// CLI subcommands and metadata configuration.
  public static let configuration = CommandConfiguration(
    commandName: "zip-builder",
    abstract: "Tool for converting a Package.swift file into an XCode project, and packaging it as a XCFramework/zip file.",
    discussion: """
      A note on logging: by default, only log levels "info" and above are logged. For further \
    debugging, you can set the "LOG_LEVEL" environment variable to a different minimum level \
    (eg; "debug").
    """,
    subcommands: [
      Plan.self,
    ],
    defaultSubcommand: Plan.self
  )

  /// Initializes the CLI root command.
  public init() {}

  /// Validates CLI arguments and configures swift-log logging bootstrap.
  public mutating func validate() throws {
    LoggingConfig.bootstrap()
  }
}
