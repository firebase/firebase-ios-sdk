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

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
import Foundation

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
public extension Firestore {
  /// Loads a Firestore bundle into the local cache.
  /// - Parameter bundleData: Data from the bundle to be loaded.
  /// - Throws: `Error` if the bundle data cannot be parsed.
  /// - Returns: The final `LoadBundleTaskProgress` that contains the total number of documents
  /// loaded.
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
  /// - Returns: The final `LoadBundleTaskProgress` that contains the total number of documents
  /// loaded.
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

  /// Executes the given updateBlock and then attempts to commit the changes applied within an
  /// atomic
  /// transaction.
  ///
  /// The maximum number of writes allowed in a single transaction is 500, but note that each
  /// usage of
  /// `FieldValue.serverTimestamp()`, `FieldValue.arrayUnion()`, `FieldValue.arrayRemove()`, or
  /// `FieldValue.increment()` inside a transaction counts as an additional write.
  ///
  /// In the `updateBlock`, a set of reads and writes can be performed atomically using the
  /// `Transaction` object passed to the block. After the `updateBlock` is run, Firestore will
  /// attempt
  /// to apply the changes to the server. If any of the data read has been modified outside of
  /// this
  /// transaction since being read, then the transaction will be retried by executing the
  /// `updateBlock`
  /// again. If the transaction still fails after 5 retries, then the transaction will fail.
  ///
  /// Since the `updateBlock` may be executed multiple times, it should avoiding doing anything
  /// that
  /// would cause side effects.
  ///
  /// Any value maybe be returned from the `updateBlock`. If the transaction is successfully
  /// committed,
  /// then the completion block will be passed that value. The `updateBlock` also has an `NSError`
  /// out
  /// parameter. If this is set, then the transaction will not attempt to commit, and the given
  /// error
  /// will be returned.
  ///
  /// The `Transaction` object passed to the `updateBlock` contains methods for accessing
  /// documents
  /// and collections. Unlike other firestore access, data accessed with the transaction will not
  /// reflect local changes that have not been committed. For this reason, it is required that all
  /// reads are performed before any writes. Transactions must be performed while online.
  /// Otherwise,
  /// reads will fail, the final commit will fail, and this function will return an error.
  ///
  /// - Parameter updateBlock The block to execute within the transaction context.
  /// - Throws Throws an error if the transaction could not be committed, or if an error was
  /// explicitly specified in the `updateBlock` parameter.
  /// - Returns Returns the value returned in the `updateBlock` parameter if no errors occurred.
  func runTransaction(_ updateBlock: @escaping (Transaction, NSErrorPointer)
    -> Any?) async throws -> Any? {
    // This needs to be wrapped in order to express a nullable return value upon success.
    // See https://github.com/firebase/firebase-ios-sdk/issues/9426 for more details.
    return try await withCheckedThrowingContinuation { continuation in
      self.runTransaction(updateBlock) { anyValue, error in
        if let err = error {
          continuation.resume(throwing: err)
        } else {
          continuation.resume(returning: anyValue)
        }
      }
    }
  }
}
