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
    /// - Throws: `Error` if the bundle data cannot be parsed.
    /// - Returns: The final `LoadBundleTaskProgress` that contains the total number of documents loaded.
    func loadBundle(_ bundleData: Data) async throws -> LoadBundleTaskProgress {
      return try await withCheckedThrowingContinuation { continuation in
        self.loadBundle(bundleData) { progress, error in
          if let err = error {
            continuation.resume(throwing: err)
          } else {
            // Our callbacks guarantee that we either return an error or a progress event.
            continuation.resume(returning: progress!)
          }
        }
      }
    }

    /// Loads a Firestore bundle into the local cache.
    /// - Parameter bundleStream: An input stream from which the bundle can be read.
    /// - Throws: `Error` if the bundle stream cannot be parsed.
    /// - Returns: The final `LoadBundleTaskProgress` that contains the total number of documents loaded.
    func loadBundle(_ bundleStream: InputStream) async throws -> LoadBundleTaskProgress {
      return try await withCheckedThrowingContinuation { continuation in
        self.loadBundle(bundleStream) { progress, error in
          if let err = error {
            continuation.resume(throwing: err)
          } else {
            // Our callbacks guarantee that we either return an error or a progress event.
            continuation.resume(returning: progress!)
          }
        }
      }
    }
  }
#endif
