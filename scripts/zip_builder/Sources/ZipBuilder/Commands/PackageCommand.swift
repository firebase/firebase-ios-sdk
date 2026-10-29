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

struct PackageCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "package",
    abstract: "Package the .xcframeworks into the distribution folder and zip."
  )

  @OptionGroup var options: SharedOptions
  @OptionGroup var logging: LoggingOptions

  @Option(help: "Use this plan instead of planning again.")
  var plan: String?

  @Option(help: "Use these .xcframeworks instead of building again.")
  var xcframeworks: String?

  @Option(help: "Sign every unsigned .xcframework with this identity (\"-\" for ad-hoc).")
  var sign: String?

  @Option(help: "The framework cache, when building again.")
  var cacheDir = FrameworkCache.defaultDirectory

  @Flag(help: "After building, remove the cache entries this build didn't use.")
  var pruneCache = false

  func run() async throws {
    logging.apply()
    let config = try options.loadConfig()
    let version = try options.releaseVersion(config) // for the archive name
    let plan = try await options.loadOrMakePlan(plan, config)
    let xcframeworks = if let xcframeworks {
      xcframeworks
    } else {
      try await options.build(plan, cacheDir: cacheDir, pruneCache: pruneCache)
    }
    _ = try await options.package(plan, config, xcframeworks: xcframeworks, sign: sign,
                                  version: version)
  }
}
