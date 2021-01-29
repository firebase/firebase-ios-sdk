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

enum RequestType: EnumerableFlag {
  case presubmit
  case merge
}

struct CoverageReportGenerator: ParsableCommand {
  @Flag()
  var requestType: RequestType

  @Argument()
  var repo: String

  @Option()
  var commit: String

  @Option()
  var token: String

  @Option()
  var xcresultDir: String

  @Option()
  var logLink: String

  @Option()
  var pullRequestNum: Int?

  @Option()
  var pullRequestNote: String?

  @Option()
  var baseCommit: String?

  @Option()
  var branch: String?

  func run() throws {
    if let coverageRequest = try combineCodeCoverageResultBundles(
      from: URL(fileURLWithPath: xcresultDir),
      log: logLink
    ) {
      sendMetricsServiceRequest(
        repo: repo,
        commits: commit,
        jsonContent: coverageRequest.toData(),
        token: token,
        is_presubmit: requestType == RequestType.presubmit,
        branch: branch,
        pullRequest: pullRequestNum,
        pullRequestNote: pullRequestNote,
        baseCommit: baseCommit
      )
    } else {
      print("coverageRequest is nil.")
    }
  }
}

CoverageReportGenerator.main()
