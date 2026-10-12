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
import Logging
import Util

/// Command for building the integration test app for a given SDK.
public struct Build: ParsableCommand {
  public static let configuration = CommandConfiguration(
    abstract: "Build the integration test app for a given SDK.",
    usage: """
      build [--overwrite] [--secrets <file_path>] [--xcode <version_or_path>] [--platforms <platforms> ...] [<sdk>]

      build --xcode Xcode_16.4.0 --platforms iOS AI
    """
  )

  @OptionGroup
  var options: CommonTestOptions

  static let log: Logger = .init(label: "Build")

  public init() {}

  public func run() throws {
    let xcodePath = try options.resolveXcodePath(logger: Self.log)
    try options.withDecryptedSecrets(logger: Self.log) {
      try options.runBuildScript(
        method: "build",
        actionDescription: "Building integration test app",
        xcodePath: xcodePath,
        logger: Self.log
      )
    }
  }
}
