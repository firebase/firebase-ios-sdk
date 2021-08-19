/*
 * Copyright 2021 Google LLC
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
import Utils

enum RequestType: EnumerableFlag {
  case presubmit
  case merge
}

struct BinarySizeReportGenerator: ParsableCommand {
  @Option(
    help: "Cocoapods-size tool directory from https://github.com/google/cocoapods-size.",
    transform: URL.init(fileURLWithPath:)
  )
  var binarySizeToolDir: URL

  @Option(help: "Local SDK repo.", transform: URL.init(fileURLWithPath:))
  var SDKRepoDir: URL

  @Option(parsing: .upToNextOption, help: "SDKs to be measured.")
  var SDK: [String]

  @Option(help: "SDKs to be measured.")
  var logPath: String

  func run() throws {
      print("----")
      print(SDK)
      print(SDKRepoDir)
      print(logPath)

     let binarySizeRequest = try CreateMetricsRequestData(
        SDK: SDK,
        SDKRepoDir: SDKRepoDir,
        logPath: logPath)
     print (binarySizeRequest.toData())
  }
}

BinarySizeReportGenerator.main()
