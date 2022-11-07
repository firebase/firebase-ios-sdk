/*
 * Copyright 2022 Google LLC
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
import FirebaseFirestore

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public extension LoadBundleTask {
  var taskProgress: AsyncThrowingStream<LoadBundleTaskProgress, Error> {
    AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      let observerHandle: LoadBundleObserverHandle = self.addObserver { progress in
        switch progress.state {
        case .error:
          guard let error = progress.error else {
            fatalError("Unknown progress error.")
          }
          continuation.finish(throwing: error)
        case .success:
          continuation.yield(progress)
          continuation.finish()
        case .inProgress:
          continuation.yield(progress)
        @unknown default:
          fatalError("Unknown progress state: \(progress.state)")
        }
      }
      continuation.onTermination = { @Sendable _ in
        self.removeObserverWith(handle: observerHandle)
      }
    }
  }
}
