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
 * Task which provides the ability to delete an object in Firebase Storage.
 */
class StorageDeleteTask: StorageTask, StorageTaskManagement {
  private var fetcher: GTMSessionFetcher?
  private var fetcherCompletion: ((Data?, NSError?) -> Void)?
  private var taskCompletion: ((_ error: Error?) -> Void)?

  init(reference: StorageReference,
       fetcherService: GTMSessionFetcherService,
       queue: DispatchQueue,
       completion: ((_: Error?) -> Void)?) {
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
    let completion = taskCompletion
    taskCompletion = { (error: Error?) in
      completion?(error)
      // Reference self in completion handler in order to retain self until completion is called.
      self.taskCompletion = nil
    }
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      self.state = .queueing
      var request = self.baseRequest
      request.httpMethod = "DELETE"
      request.timeoutInterval = self.reference.storage.maxOperationRetryTime

      let fetcher = self.fetcherService.fetcher(with: request)
      fetcher.comment = "DeleteTask"
      self.fetcher = fetcher

      self.fetcherCompletion = { [weak self] (data: Data?, error: NSError?) in
        guard let self = self else { return }
        if let error, self.error == nil {
          self.error = StorageErrorCode.error(withServerError: error, ref: self.reference)
        }
        self.taskCompletion?(self.error)
        self.fetcherCompletion = nil
      }

      self.fetcher?.beginFetch { [weak self] data, error in
        self?.fetcherCompletion?(data, error as? NSError)
      }
    }
  }
}
