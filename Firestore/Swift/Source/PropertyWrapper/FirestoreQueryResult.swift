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

public class FirestoreQueryResult<T: FirestoreDocumentReferable>: Collection,
  RandomAccessCollection {
  public var items: [T] = []

  public var results: Result<[T], Error> = .success([])

  public var error: Error?

  internal var delete: (String) -> Void = { _ in }
  internal var add: (T) -> Void = { _ in }

  public func removeDocument(at indexSet: IndexSet) {
    for index in indexSet {
      let documentID = items[index].documentID

      delete(documentID)
      items.remove(at: index)
    }
  }

  public func addDocument(_ document: T) {
    add(document)
  }

  public typealias Index = Int
  public typealias Element = T

  public var startIndex: Int { items.startIndex }
  public var endIndex: Int { items.endIndex }

  public subscript(position: Int) -> T {
    return items[position]
  }

  public func index(after i: Int) -> Int {
    items.index(after: i)
  }
}
