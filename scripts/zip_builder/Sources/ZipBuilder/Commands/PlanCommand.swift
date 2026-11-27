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

struct PlanCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "plan",
    abstract: "Plan the release and write plan.json."
  )

  @OptionGroup var options: SharedOptions
  @OptionGroup var logging: LoggingOptions

  func run() async throws {
    logging.apply()
    let config = try options.loadConfig()
    let plan = try await options.makeCustomizedPlan(config)
    let planURL = try options.writePlan(plan)
    logger.info("""
    Planned \(plan.frameworks.count) frameworks, \(plan.binaries.count) binaries and \
    \(plan.folders.count) folders: \(planURL.path)
    """)
  }
}
