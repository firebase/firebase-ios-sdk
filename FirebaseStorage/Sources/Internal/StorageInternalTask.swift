// Copyright 2024 Google LLC
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

/// Implement StorageTasks that are not directly exposed via the public API.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StorageInternalTask: StorageTask {
  private var fetcher: GTMSessionFetcher?

  @discardableResult
  init(reference: StorageReference,
       queue: DispatchQueue,
       request: URLRequest? = nil,
       httpMethod: String,
       fetcherComment: String,
       completion: ((_: Data?, _: Error?) -> Void)?) {
    super.init(reference: reference, queue: queue)

    // Prepare a task and begins execution.
    dispatchQueue.async { [self] in
      self.state = .queueing
      Task {
        let fetcherService = await StorageFetcherService.shared.service(reference.storage)
        var request = request ?? self.baseRequest
        request.httpMethod = httpMethod
        request.timeoutInterval = self.reference.storage.maxOperationRetryTime

        let fetcher = fetcherService.fetcher(with: request)
        fetcher.comment = fetcherComment
        self.fetcher = fetcher
        let callbackQueue = reference.storage.callbackQueue
        do {
          let data = try await self.fetcher?.beginFetch()
          callbackQueue.async {
            completion?(data, nil)
          }
        } catch {
          callbackQueue.async {
            completion?(nil, StorageErrorCode.error(withServerError: error as NSError,
                                                    ref: self.reference))
          }
        }
      }
    }
  }

  deinit {
    self.fetcher?.stopFetching()
  }
}
