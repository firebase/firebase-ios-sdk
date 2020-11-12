/*
 * Copyright 2020 Google LLC
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

@available(swift 5.0)
extension Firestore {
  /// Executes the given updateBlock and then attempts to commit the changes applied within an
  /// atomic transaction.
  ///
  /// The maximum number of writes allowed in a single transaction is 500, but note that each usage
  /// of `FieldValue.serverTimestamp()`, `FieldValue.arrayUnion()`, `FieldValue.arrayRemove()`, or
  /// `FieldValue.increment()` inside a transaction counts as an additional write.
  ///
  /// In the updateBlock, a set of reads and writes can be performed atomically using the
  /// `Transaction` object passed to the block. After the updateBlock is run, Firestore will attempt
  /// to apply the changes to the server. If any of the data read has been modified outside of this
  /// transaction since being read, then the transaction will be retried by executing the
  /// updateBlock again. If the transaction still fails after 5 retries, then the transaction will
  /// fail.
  ///
  /// Since the updateBlock may be executed multiple times, it should avoiding doing anything that
  /// would cause side effects.
  ///
  /// Any value maybe be returned from the updateBlock. If the transaction is successfully
  /// committed, then the completion block will be passed that value. If the updateBlock throws an
  /// error, then the transaction will not attempt to commit, and the thrown error will be passed to
  /// the completion block in result.
  ///
  /// The `Transaction` object passed to the updateBlock contains methods for accessing documents
  /// and collections. Unlike other firestore access, data accessed with the transaction will not
  /// reflect local changes that have not been committed. For this reason, it is required that all
  /// reads are performed before any writes. Transactions must be performed while online.
  /// Otherwise, reads will fail, the final commit will fail, and the completion block will return
  /// an error.
  ///
  /// - Parameters:
  ///   - updateBlock: The closure to execute within the transaction context.
  ///   - transaction: The` Transaction` object that handle the transaction.
  ///   - completion: The block to call with the result or error of the transaction. This block will
  ///    run even if the client is offline, unless the process is killed.
  ///   - result: The result of the transaction. On success it contains the value passed in the
  ///    updateBlock, otherwise an `Error`.
  func runTransaction<T>(_ updateBlock: @escaping (_ transaction: Transaction) throws -> T,
                         completion: @escaping (Result<T, Error>) -> Void) {
    runTransaction({ transaction, errorPointer in
      do {
        return try updateBlock(transaction)
      } catch {
        errorPointer?.pointee = error as NSError
        return nil
      }
    }, completion: mapResultCompletion(completion))
  }
}

/// Returns a closure mapped from the a given closure with a `Result` parameter.
///
/// - Precondition:
///   UpdateBlock return type must match completion argument type
///
///   Internal return value and error must not both be nil.
///
/// - Parameters:
///   - completion: The closure to map.
///   - result: The parameter of the closure to map.
/// - Returns: A closure mapped from the given closure.
private func mapResultCompletion<T>(_ completion: @escaping (_ result: Result<T, Error>) -> Void)
  -> ((Any?, Error?) -> Void) {
  return { value, error in
    if let value = value {
      if let value = value as? T {
        completion(.success(value))
      } else {
        fatalError("UpdateBlock return type must match completion argument type")
      }
    } else if let error = error {
      completion(.failure(error))
    } else {
      fatalError("Internal return value and error must not both be nil")
    }
  }
}
