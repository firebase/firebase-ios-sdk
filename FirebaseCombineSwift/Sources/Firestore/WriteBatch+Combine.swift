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

  extension WriteBatch {
    /// Commits all of the writes in this write batch as a single atomic unit.
    ///
    /// - Returns: A publisher emitting a `Void` value once all of the writes in the batch
    ///   have been successfully written to the backend as an atomic unit. This publisher will only
    ///   emits when the client is online and the commit has completed against the server.
    ///   The changes will be visible immediately.
    public func commit() -> Future<Void, Error> {
      Future { promise in
        self.commit { error in
          if let error = error {
            promise(.failure(error))
          } else {
            promise(.success(()))
          }
        }
      }
    }
  }

#endif
