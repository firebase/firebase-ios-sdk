import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

func sendMetricsServiceRequest(repo: String, commits: String, jsonContent: Data, token: String,
                               is_presubmit: Bool, branch: String?, pullRequest: Int?,
                               pullRequestNote: String?, baseCommit: String?) {
  var request: URLRequest
  let endpoint =
    "https://sdk-metrics-service-tv5rmd4a6q-uc.a.run.app/repos/\(repo)/commits/\(commits)/reports?"
  var pathPara: [String] = []
  if is_presubmit {
    guard let pr = pullRequest else {
      print(
        "The pull request number should be specified for an API pull-request request to the Metrics Service."
      )
      return
    }
    guard let bc = baseCommit else {
      print(
        "Base commit hash should be specified for an API pull-request request to the Metrics Service."
      )
      return
    }
    pathPara.append("pull_request=\(String(pr))")
    if let note = pullRequestNote { pathPara.append("note=\(note)") }
    pathPara.append("base_commit=\(bc)")
  } else {
    guard let branch = branch else {
      print("Targeted merged branch should be specified.")
      return
    }
    pathPara.append("branch=\(branch)")
  }

  let webURL = endpoint + pathPara.joined(separator: "&")
  guard let metricsServiceURL = URL(string: webURL) else {
    print("URL Path \(webURL) is not valid.")
    return
  }
  request = URLRequest(url: metricsServiceURL, timeoutInterval: Double.infinity)

  request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
  request.addValue("application/json", forHTTPHeaderField: "Content-Type")

  request.httpMethod = "POST"
  request.httpBody = jsonContent

  let task = URLSession.shared.dataTask(with: request) { data, response, error in
    guard let data = data else {
      print(String(describing: error))
      return
    }
    print(String(data: data, encoding: .utf8)!)
  }

  task.resume()
}
