// Copyright 2023 Google LLC
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

typealias AuthSerialTaskCompletionBlock = () -> Void

class AuthSerialTaskQueue: NSObject {
  private let dispatchQueue: DispatchQueue

  override init() {
    dispatchQueue = DispatchQueue(
      label: "com.google.firebase.auth.serialTaskQueue",
      target: kAuthGlobalWorkQueue
    )
    super.init()
  }

  func enqueueTask(_ task: @escaping ((_ complete: @escaping AuthSerialTaskCompletionBlock)
      -> Void)) {
    dispatchQueue.async {
      self.dispatchQueue.suspend()
      task {
        self.dispatchQueue.resume()
      }
    }
  }
}
