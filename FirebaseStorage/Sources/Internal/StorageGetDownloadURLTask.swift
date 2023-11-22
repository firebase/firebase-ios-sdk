// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

/**
 * Task which provides the ability to get a download URL for an object in Firebase Storage.
 */
class StorageGetDownloadURLTask: StorageTask, StorageTaskManagement {
  private var fetcher: GTMSessionFetcher?
  private var fetcherCompletion: ((Data?, NSError?) -> Void)?
  private var taskCompletion: ((_ downloadURL: URL?, _: Error?) -> Void)?

  init(reference: StorageReference,
       fetcherService: GTMSessionFetcherService,
       queue: DispatchQueue,
       completion: ((_: URL?, _: Error?) -> Void)?) {
    super.init(reference: reference, service: fetcherService, queue: queue)
    taskCompletion = completion
  }

  deinit {
    self.fetcher?.stopFetching()
  }

  /**
   * Prepares a task and begins execution.
   */
  func enqueue() {
    if let completion = taskCompletion {
      taskCompletion = { (url: URL?, error: Error?) in
        completion(url, error)
        // Reference self in completion handler in order to retain self until completion is called.
        self.taskCompletion = nil
      }
    }
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      var request = self.baseRequest
      request.httpMethod = "GET"
      request.timeoutInterval = self.reference.storage.maxOperationRetryTime

      let fetcher = self.fetcherService.fetcher(with: request)
      fetcher.comment = "GetDownloadURLTask"
      self.fetcher = fetcher

      self.fetcherCompletion = { [weak self] (data: Data?, error: NSError?) in
        guard let self = self else { return }
        var downloadURL: URL?
        if let error = error {
          if self.error == nil {
            self.error = StorageErrorCode.error(withServerError: error, ref: self.reference)
          }
        } else {
          if let data = data,
             let responseDictionary = try? JSONSerialization
             .jsonObject(with: data) as? [String: Any] {
            downloadURL = self.downloadURLFromMetadataDictionary(responseDictionary)
            if downloadURL == nil {
              self.error = NSError(domain: StorageErrorDomain,
                                   code: StorageErrorCode.unknown.rawValue,
                                   userInfo: [NSLocalizedDescriptionKey:
                                     "Failed to retrieve a download URL."])
            }
          } else {
            self.error = StorageErrorCode.error(withInvalidRequest: data)
          }
        }
        self.taskCompletion?(downloadURL, self.error)
        self.fetcherCompletion = nil
      }

      self.fetcher?.beginFetch { [weak self] data, error in
        self?.fetcherCompletion?(data, error as? NSError)
      }
    }
  }

  func downloadURLFromMetadataDictionary(_ dictionary: [String: Any]) -> URL? {
    let downloadTokens = dictionary["downloadTokens"]
    guard let downloadTokens = downloadTokens as? String,
          downloadTokens.count > 0 else {
      return nil
    }
    let downloadTokenArray = downloadTokens.components(separatedBy: ",")
    let bucket = dictionary["bucket"] ?? "<error: missing bucket>"
    let path = dictionary["name"] as? String ?? "<error: missing path name>"
    let fullPath = "/v0/b/\(bucket)/o/\(StorageUtils.GCSEscapedString(path))"
    var components = URLComponents()
    components.scheme = reference.storage.scheme
    components.host = reference.storage.host
    components.port = reference.storage.port
    components.percentEncodedPath = fullPath

    // The backend can return an arbitrary number of download tokens, but we only expose the first
    // token via the download URL.
    let altItem = URLQueryItem(name: "alt", value: "media")
    let tokenItem = URLQueryItem(name: "token", value: downloadTokenArray[0])
    components.queryItems = [altItem, tokenItem]
    return components.url
  }
}
