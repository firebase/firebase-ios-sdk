import ArgumentParser
import Foundation

enum RequestType: EnumerableFlag{
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
  var pullRequestNum: Int?

  @Option()
  var pullRequestNote: String?

  @Option()
  var baseCommit: String?

  @Option()
  var branch: String?

  func run() throws {
    if let coverageRequest = combineCodeCoverageResultBundles(from: URL(fileURLWithPath: xcresultDir)){
      sendMetricsServiceRequest(
        repo: repo,
        commits: commit,
        jsonContent: coverageRequest.toData(),
        token: token,
        is_presubmit: requestType == RequestType.presubmit,
        branch: branch,
        pullRequest: pullRequestNum,
        pullRequestNote: pullRequestNote,
        baseCommit: baseCommit)
    } else {
      print("coverageRequest is nil.")
    }
  }
}

CoverageReportGenerator.main()
