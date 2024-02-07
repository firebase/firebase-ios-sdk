// Copyright 2021 Google LLC
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

#if canImport(Combine) && swift(>=5.0)

  import Combine
  import FirebaseFirestore

  @available(swift 5.0)
  @available(iOS 13.0, macOS 10.15, macCatalyst 13.0, tvOS 13.0, watchOS 6.0, *)
  public extension Firestore {
    /// Executes the given updateBlock and then attempts to commit the changes applied within an
    /// atomic transaction.
    ///
    /// The maximum number of writes allowed in a single transaction is 500, but note that each
    /// usage of `FieldValue.serverTimestamp()`, `FieldValue.arrayUnion()`,
    /// `FieldValue.arrayRemove()`, or `FieldValue.increment()` inside a transaction counts as an
    ///  additional write.
    ///
    /// In the updateBlock, a set of reads and writes can be performed atomically using the
    ///  `Transaction` object passed to the block. After the updateBlock is run, Firestore will
    ///  attempt to apply the changes to the server. If any of the data read has been modified
    ///  outside of this transaction since being read, then the transaction will be retried by
    ///  executing the updateBlock again. If the transaction still fails after 5 retries, then the
    ///   transaction will fail.
    ///
    /// Since the updateBlock may be executed multiple times, it should avoiding doing anything that
    /// would cause side effects.
    ///
    /// Any value maybe be returned from the updateBlock. If the transaction is successfully
    /// committed, then the completion block will be passed that value. The updateBlock also has an
    ///  `Error` out parameter. If this is set, then the transaction will not attempt to commit, and
    ///  the given error will be passed to the completion block.
    ///
    /// The `Transaction` object passed to the updateBlock contains methods for accessing documents
    ///  and collections. Unlike other firestore access, data accessed with the transaction will not
    ///  reflect local changes that have not been committed. For this reason, it is required that
    ///  all reads are performed before any writes. Transactions must be performed while online.
    ///  Otherwise, reads will fail, the final commit will fail, and the completion block will
    ///  return an error.
    ///
    /// - Parameter updateBlock: The block to execute within the transaction context.
    /// - Returns: A publisher emitting a value instance passed from the updateBlock. This block
    ///  will run even if the client is offline, unless the process is killed.
    func runTransaction<T>(_ updateBlock: @escaping (Transaction) throws -> T)
      -> Future<T, Error> {
      Future { promise in
        self.runTransaction({ transaction, errorPointer in
          do {
            return try updateBlock(transaction)
          } catch let fetchError as NSError {
            errorPointer?.pointee = fetchError
            return nil
          }
        }) { value, error in
          if let error {
            promise(.failure(error))
          } else if let value = value as? T {
            promise(.success(value))
          }
        }
      }
    }
  }

#endif
