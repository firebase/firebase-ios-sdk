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

import FirebaseFirestore
import Foundation

#if compiler(>=5.5) && canImport(_Concurrency)
  @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
  public extension Firestore {
    /// Loads a Firestore bundle into the local cache.
    /// - Parameter bundleData: Data from the bundle to be loaded.
    /// - Returns: The final `LoadBundleTaskProgress` that contains the total number of documents loaded.
    func loadBundle(_ bundleData: Data) async throws -> LoadBundleTaskProgress {
      typealias DataContinuation = CheckedContinuation<LoadBundleTaskProgress, Error>
      return try await withCheckedThrowingContinuation { (continuation: DataContinuation) in
        self.loadBundle(bundleData) { progress, error in
          if let err = error {
            continuation.resume(throwing: err)
          } else {
            continuation.resume(returning: progress!)
          }
        }
      }
    }
  }
#endif
