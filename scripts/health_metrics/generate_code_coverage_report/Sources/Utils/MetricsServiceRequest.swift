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

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public func sendMetricsServiceRequest(repo: String, commits: String, jsonContent: Data,
                                      token: String,
                                      is_presubmit: Bool, branch: String?, pullRequest: Int?,
                                      pullRequestNote: String?, baseCommit: String?) {
  var request: URLRequest
  var semaphore = DispatchSemaphore(value: 0)
  let endpoint =
    "https://api.firebase-sdk-health-metrics.com/repos/\(repo)/commits/\(commits)/reports?"
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
    if let note = pullRequestNote {
      let compatible_url_format_note = note
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
      pathPara.append("note=\(compatible_url_format_note))")
    }
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
    semaphore.signal()
  }

  task.resume()
  semaphore.wait()
}
