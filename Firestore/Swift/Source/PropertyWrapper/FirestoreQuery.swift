/*
 * Copyright 2021 Google
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
import SwiftUI

public enum FIRPredicate {
  case isEqualTo(_ lhs: String, _ rhs: Any)

  case isIn(_ lhs: String, _ rhs: [Any])
  case isNotIn(_ lhs: String, _ rhs: [Any])

  case arrayContains(_ lhs: String, _ rhs: Any)
  case arrayContainsAny(_ lhs: String, _ rhs: [Any])

  case isLessThan(_ lhs: String, _ rhs: Any)
  case isGreaterThan(_ lhs: String, _ rhs: Any)

  case isLessThanOrEqualTo(_ lhs: String, _ rhs: Any)
  case isGreaterThanOrEqualTo(_ lhs: String, _ rhs: Any)

  case orderBy(_ lhs: String, _ rhs: Bool)

  case limitTo(_ lhs: Int)

  /*
   Factory methods to expose the underlying enum cases with a nicer development experience and improved semantics.
   */
  public static func whereField(_ lhs: String, isEqualTo rhs: Any) -> FIRPredicate {
    .isEqualTo(lhs, rhs)
  }

  public static func whereField(_ lhs: String, isIn rhs: [Any]) -> FIRPredicate {
    .isIn(lhs, rhs)
  }

  public static func whereField(_ lhs: String, isNotIn rhs: [Any]) -> FIRPredicate {
    .isNotIn(lhs, rhs)
  }

  public static func whereField(_ lhs: String, arrayContains rhs: Any) -> FIRPredicate {
    .arrayContains(lhs, rhs)
  }

  public static func whereField(_ lhs: String, arrayContainsAny rhs: [Any]) -> FIRPredicate {
    .arrayContainsAny(lhs, rhs)
  }

  public static func whereField(_ lhs: String, isLessThan rhs: Any) -> FIRPredicate {
    .isLessThan(lhs, rhs)
  }

  public static func whereField(_ lhs: String, isGreaterThan rhs: Any) -> FIRPredicate {
    .isGreaterThan(lhs, rhs)
  }

  public static func whereField(_ lhs: String, isLessThanOrEqualTo rhs: Any) -> FIRPredicate {
    .isLessThanOrEqualTo(lhs, rhs)
  }

  public static func whereField(_ lhs: String, isGreaterThanOrEqualTo rhs: Any) -> FIRPredicate {
    .isGreaterThanOrEqualTo(lhs, rhs)
  }

  public static func order(by lhs: String, descending rhs: Bool = false) -> FIRPredicate {
    .orderBy(lhs, rhs)
  }

  public static func limit(to lhs: Int) -> FIRPredicate {
    .limitTo(lhs)
  }
}

@available(iOS 13.0, *)
internal class QueryStore<T: Decodable>: ObservableObject {
  @Published var items: [T] = []

  private let firestore = Firestore.firestore()
  private var listener: ListenerRegistration? = nil

  init(collectionPath: String, predicates: [FIRPredicate]) {
    setupListener(from: collectionPath, withPredicates: predicates)
  }

  deinit {
    removeListener()
  }

  private func setupListener(from collectionPath: String,
                             withPredicates predicates: [FIRPredicate]) {
    var query: Query = firestore.collection(collectionPath)

    for predicate in predicates {
      switch predicate {
      case let .isEqualTo(lhs, rhs):
        query = query.whereField(lhs, isEqualTo: rhs)
      case let .isIn(lhs, rhs):
        query = query.whereField(lhs, in: rhs)
      case let .isNotIn(lhs, rhs):
        query = query.whereField(lhs, notIn: rhs)
      case let .arrayContains(lhs, rhs):
        query = query.whereField(lhs, arrayContains: rhs)
      case let .arrayContainsAny(lhs, rhs):
        query = query.whereField(lhs, arrayContainsAny: rhs)
      case let .isLessThan(lhs, rhs):
        query = query.whereField(lhs, isLessThan: rhs)
      case let .isGreaterThan(lhs, rhs):
        query = query.whereField(lhs, isGreaterThan: rhs)
      case let .isLessThanOrEqualTo(lhs, rhs):
        query = query.whereField(lhs, isLessThanOrEqualTo: rhs)
      case let .isGreaterThanOrEqualTo(lhs, rhs):
        query = query.whereField(lhs, isGreaterThanOrEqualTo: rhs)
      case let .orderBy(lhs, rhs):
        query = query.order(by: lhs, descending: rhs)
      case let .limitTo(lhs):
        query = query.limit(to: lhs)
      }
    }

    listener = query.addSnapshotListener { [weak self] snapshot, error in
      if let error = error {
        print(error)
        self?.items = []
        return
      }

      guard let snapshot = snapshot else {
        print("FirestoreQuery: Registering the SnapshotListener returned a bad snapshot.")
        self?.items = []
        return
      }

      self?.items = snapshot.documents.compactMap { document in
        try? document.data(as: T.self)
      }
    }
  }

  private func removeListener() {
    listener?.remove()
  }
}

@available(iOS 14.0, *)
@propertyWrapper
public struct FirestoreQuery<T: Decodable>: DynamicProperty {
  @StateObject private var store: QueryStore<T>

  public private(set) var wrappedValue: [T] {
    get {
      store.items
    }
    nonmutating set {
      store.items = newValue
    }
  }

  public init(collectionPath: String, predicates: [FIRPredicate] = []) {
    _store =
      StateObject(wrappedValue: QueryStore<T>(collectionPath: collectionPath,
                                              predicates: predicates))
  }
}
