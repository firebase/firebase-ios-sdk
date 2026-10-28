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

struct BuildCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "build",
    abstract: "Build the .xcframeworks, compiling only frameworks missing from the cache."
  )

  @OptionGroup var options: SharedOptions
  @OptionGroup var logging: LoggingOptions

  @Option(help: "Use this plan instead of planning again.")
  var plan: String?

  @Option(help: "Build this hand-edited project as-is, without the cache.")
  var project: String?

  @Option(help: "The framework cache.")
  var cacheDir = FrameworkCache.defaultDirectory

  func run() async throws {
    logging.apply()
    let config = try options.loadConfig()
    let plan = try await options.loadOrMakePlan(plan, config)
    _ = try await options.build(plan, cacheDir: cacheDir, project: project)
  }
}
