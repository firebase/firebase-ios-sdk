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

/// Implement StorageTasks that are not directly exposed via the public API.
@preconcurrency
class StorageInternalTask: StorageTask, @unchecked Sendable {
  @discardableResult
  init(reference: StorageReference,
       queue: DispatchQueue,
       request: URLRequest? = nil,
       httpMethod: String,
       completion: ((_: Data?, _: Error?) -> Void)?) {
    super.init(reference: reference, queue: queue)

    // Prepare a task and begins execution.
    dispatchQueue.async { [self] in
      stateLock.withLock {
        self.state = .queueing
      }
      Task {
        let storage = self.reference.storage
        var request = request ?? self.baseRequest
        request.httpMethod = httpMethod
        request.timeoutInterval = storage.maxOperationRetryTime

        let callbackQueue = storage.callbackQueue
        do {
          let data = try await StorageHTTPService.shared.data(
            for: request,
            storage: storage,
            maxRetryTime: storage.maxOperationRetryTime
          )
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
}
