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
import SwiftUI

public enum QueryPredicate {
  case isEqualTo(_ field: String, _ value: Any)

  case isIn(_ field: String, _ values: [Any])
  case isNotIn(_ field: String, _ values: [Any])

  case arrayContains(_ field: String, _ value: Any)
  case arrayContainsAny(_ field: String, _ values: [Any])

  case isLessThan(_ field: String, _ value: Any)
  case isGreaterThan(_ field: String, _ value: Any)

  case isLessThanOrEqualTo(_ field: String, _ value: Any)
  case isGreaterThanOrEqualTo(_ field: String, _ value: Any)

  case orderBy(_ field: String, _ value: Bool)

  case limitTo(_ value: Int)
  case limitToLast(_ value: Int)

  /*
   Factory methods to expose the underlying enum cases with a nicer development experience and improved semantics.
   */
  public static func whereField(_ field: String, isEqualTo value: Any) -> QueryPredicate {
    .isEqualTo(field, value)
  }

  public static func whereField(_ field: String, isIn values: [Any]) -> QueryPredicate {
    .isIn(field, values)
  }

  public static func whereField(_ field: String, isNotIn values: [Any]) -> QueryPredicate {
    .isNotIn(field, values)
  }

  public static func whereField(_ field: String, arrayContains value: Any) -> QueryPredicate {
    .arrayContains(field, value)
  }

  public static func whereField(_ field: String,
                                arrayContainsAny values: [Any]) -> QueryPredicate {
    .arrayContainsAny(field, values)
  }

  public static func whereField(_ field: String, isLessThan value: Any) -> QueryPredicate {
    .isLessThan(field, value)
  }

  public static func whereField(_ field: String, isGreaterThan value: Any) -> QueryPredicate {
    .isGreaterThan(field, value)
  }

  public static func whereField(_ field: String,
                                isLessThanOrEqualTo value: Any) -> QueryPredicate {
    .isLessThanOrEqualTo(field, value)
  }

  public static func whereField(_ field: String,
                                isGreaterThanOrEqualTo value: Any) -> QueryPredicate {
    .isGreaterThanOrEqualTo(field, value)
  }

  public static func order(by field: String, descending value: Bool = false) -> QueryPredicate {
    .orderBy(field, value)
  }

  public static func limit(to value: Int) -> QueryPredicate {
    .limitTo(value)
  }
    
  public static func limit(toLast value: Int) -> QueryPredicate {
    .limitToLast(value)
  }
}

@available(iOS 13.0, *)
internal class FirestoreQueryObservable<T: Decodable>: ObservableObject {
  @Published var items: [T] = []

  private let firestore = Firestore.firestore()
  private var listener: ListenerRegistration? = nil

  init(collectionPath: String, predicates: [QueryPredicate]) {
    setupListener(from: collectionPath, withPredicates: predicates)
  }

  deinit {
    removeListener()
  }

  private func setupListener(from collectionPath: String,
                             withPredicates predicates: [QueryPredicate]) {
    var query: Query = firestore.collection(collectionPath)

    for predicate in predicates {
      switch predicate {
      case let .isEqualTo(field, value):
        query = query.whereField(field, isEqualTo: value)
      case let .isIn(field, values):
        query = query.whereField(field, in: values)
      case let .isNotIn(field, values):
        query = query.whereField(field, notIn: values)
      case let .arrayContains(field, value):
        query = query.whereField(field, arrayContains: value)
      case let .arrayContainsAny(field, values):
        query = query.whereField(field, arrayContainsAny: values)
      case let .isLessThan(field, value):
        query = query.whereField(field, isLessThan: value)
      case let .isGreaterThan(field, value):
        query = query.whereField(field, isGreaterThan: value)
      case let .isLessThanOrEqualTo(field, value):
        query = query.whereField(field, isLessThanOrEqualTo: value)
      case let .isGreaterThanOrEqualTo(field, value):
        query = query.whereField(field, isGreaterThanOrEqualTo: value)
      case let .orderBy(field, value):
        query = query.order(by: field, descending: value)
      case let .limitTo(field):
        query = query.limit(to: field)
      case let .limitToLast(field):
        query = query.limit(toLast: field)
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
  @StateObject private var firestoreQueryObservable: FirestoreQueryObservable<T>

  public var wrappedValue: [T] {
    get {
        firestoreQueryObservable.items
    }
  }

  public init(collectionPath: String, predicates: [QueryPredicate] = []) {
    _firestoreQueryObservable =
      StateObject(wrappedValue: FirestoreQueryObservable<T>(collectionPath: collectionPath,
                                                            predicates: predicates))
  }
}
