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
internal class StorageDeleteTask: StorageTask, StorageTaskManagement {
  private var fetcher: GTMSessionFetcher?
  private var fetcherCompletion: ((Data?, NSError?) -> Void)?
  private var taskCompletion: ((_ error: Error?) -> Void)?

  internal init(reference: StorageReference,
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
  internal func enqueue() {
    weak var weakSelf = self
    DispatchQueue.global(qos: .background).async {
      guard let strongSelf = weakSelf else { return }
      strongSelf.state = .queueing
      var request = strongSelf.baseRequest
      request.httpMethod = "DELETE"
      request.timeoutInterval = strongSelf.reference.storage.maxOperationRetryTime

      let callback = strongSelf.taskCompletion
      strongSelf.taskCompletion = nil

      let fetcher = strongSelf.fetcherService.fetcher(with: request)
      fetcher.comment = "DeleteTask"
      strongSelf.fetcher = fetcher

      strongSelf.fetcherCompletion = { (data: Data?, error: NSError?) in
        if let error = error, self.error == nil {
          self.error = StorageErrorCode.error(withServerError: error, ref: strongSelf.reference)
        }
        callback?(self.error)
        self.fetcherCompletion = nil
      }

      strongSelf.fetcher?.beginFetch { data, error in
        let strongSelf = weakSelf
        if let fetcherCompletion = strongSelf?.fetcherCompletion {
          fetcherCompletion(data, error as? NSError)
        }
      }
    }
  }
}
