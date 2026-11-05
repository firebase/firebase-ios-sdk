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

struct ProjectCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "project",
    abstract: "Generate the full source .xcodeproj, for opening in Xcode."
  )

  @OptionGroup var options: SharedOptions
  @OptionGroup var logging: LoggingOptions

  @Option(help: "Use this plan instead of planning again.")
  var plan: String?

  func run() async throws {
    logging.apply()
    let config = try options.loadConfig()
    let plan = try await options.loadOrMakePlan(plan, config)
    let projectPath = URL(fileURLWithPath: options.workDir)
      .appendingPathComponent("\(config.release.name).xcodeproj").path
    // Linked as `build` links it with nothing cached, so `build --project` builds the same.
    let staticBinaries = try await staticBinaries(reachedByDynamicFrameworksIn: plan,
                                                  packageRoot: options.packagePath)
    try checkDynamicFrameworksLinkNothingStatic(plan, staticBinaries: staticBinaries)
    try makeProject(replacingCachedFrameworks(plan, with: [:], staticBinaries: staticBinaries),
                    packageRoot: options.packagePath, at: projectPath)
    logger.info("""
    Wrote \(projectPath) with \(plan.frameworks.count) targets and schemes \
    \(schemeDestinations(plan).map(\.name).joined(separator: ", "))
    """)
  }
}
