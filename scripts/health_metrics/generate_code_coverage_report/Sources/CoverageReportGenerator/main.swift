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

struct CoverageReportGenerator: ParsableCommand {
  @Flag(help: "Determine if the request to Metrics Service is for pull_requests or merge.")
  var requestType: RequestType

  @Argument(help: "A repo coverage data will be related to.")
  var repo: String

  @Option(
    help: "presubmit: compare the diff to the base_commit; merge: store coverage data linking to this commit."
  )
  var headCommit: String

  @Option(help: "Token to access an account of the Metrics Service")
  var token: String

  @Option(
    help: "The directory of all xcresult bundles with code coverage data. ONLY files/dirs under this directory will be searched."
  )
  var xcresultDir: String

  @Option(help: "Link to the log, leave \"\" if none.")
  var logLink: String

  @Option(
    help: "This is for presubmit request. Number of a pull request that a coverage report will be posted on."
  )
  var pullRequestNum: Int?

  @Option(help: "This is for presubmit request. Additional note for the report.")
  var pullRequestNote: String?

  @Option(
    help: "This is for presubmit request. Coverage of commit will be compared to the coverage of this base_commit."
  )
  var baseCommit: String?

  @Option(
    help: "This is for merge request. Branch here will be linked to the coverage data, with the merged commit, in the database. "
  )
  var sourceBranch: String?

  func run() throws {
    if let coverageRequest = try combineCodeCoverageResultBundles(
      from: URL(fileURLWithPath: xcresultDir),
      log: logLink
    ) {
      sendMetricsServiceRequest(
        repo: repo,
        commits: headCommit,
        jsonContent: coverageRequest.toData(),
        token: token,
        is_presubmit: requestType == RequestType.presubmit,
        branch: sourceBranch,
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
