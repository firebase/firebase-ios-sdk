/// Copyright 2022 Google LLC
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
internal class StorageUpdateMetadataTask: StorageTask, StorageTaskManagement {
  private var fetcher: GTMSessionFetcher?
  private var fetcherCompletion: ((Data?, NSError?) -> Void)?
  private var taskCompletion: ((_ metadata: StorageMetadata?, _: Error?) -> Void)?
  private var updateMetadata: StorageMetadata

  internal init(reference: StorageReference,
                fetcherService: GTMSessionFetcherService,
                queue: DispatchQueue,
                metadata: StorageMetadata,
                completion: ((_: StorageMetadata?, _: Error?) -> Void)?) {
    updateMetadata = metadata
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
    let completion = taskCompletion
    taskCompletion = { (metadata: StorageMetadata?, error: Error?) in
      completion?(metadata, error)
      // Reference self in completion handler in order to retain self until completion is called.
      self.taskCompletion = nil
    }
    dispatchQueue.async { [weak self] in
      guard let self = self else { return }
      var request = self.baseRequest
      let updateDictionary = self.updateMetadata.updatedMetadata()
      let updateData = try? JSONSerialization.data(withJSONObject: updateDictionary)
      request.httpMethod = "PATCH"
      request.timeoutInterval = self.reference.storage.maxOperationRetryTime
      request.httpBody = updateData
      request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
      if let count = updateData?.count {
        request.setValue("\(count)", forHTTPHeaderField: "Content-Length")
      }

      let fetcher = self.fetcherService.fetcher(with: request)
      fetcher.comment = "GetMetadataTask"
      self.fetcher = fetcher

      self.fetcherCompletion = { [weak self] (data: Data?, error: NSError?) in
        guard let self = self else { return }
        var metadata: StorageMetadata?
        if let error = error {
          if self.error == nil {
            self.error = StorageErrorCode.error(withServerError: error, ref: self.reference)
          }
        } else {
          if let data = data,
             let responseDictionary = try? JSONSerialization
             .jsonObject(with: data) as? [String: AnyHashable] {
            metadata = StorageMetadata(dictionary: responseDictionary)
            metadata?.fileType = .file
          } else {
            self.error = StorageErrorCode.error(withInvalidRequest: data)
          }
        }
        self.taskCompletion?(metadata, self.error)
        self.fetcherCompletion = nil
      }

      fetcher.comment = "UpdateMetadataTask"

      self.fetcher?.beginFetch { [weak self] data, error in
        self?.fetcherCompletion?(data, error as? NSError)
      }
    }
  }
}
