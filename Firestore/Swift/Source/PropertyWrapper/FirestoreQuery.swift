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

public enum QueryPredicate {
  case isEqualTo(field: String, value: Any)

  case isIn(field: String, values: [Any])
  case isNotIn(field: String, values: [Any])

  case arrayContains(field: String, value: Any)
  case arrayContainsAny(field: String, values: [Any])

  case isLessThan(field: String, value: Any)
  case isGreaterThan(field: String, value: Any)

  case isLessThanOrEqualTo(field: String, value: Any)
  case isGreaterThanOrEqualTo(field: String, value: Any)

  // -- alternative naming 2

  public static func whereField(_ name: String, isEqualTo value: Any) -> QueryPredicate {
    return .isEqualTo(field: name, value: value)
  }

  public static func whereField(_ name: String, isIn values: [Any]) -> QueryPredicate {
    return .isIn(field: name, values: values)
  }

  public static func whereField(_ name: String, isNotIn values: [Any]) -> QueryPredicate {
    return .isNotIn(field: name, values: values)
  }

  public static func whereField(_ name: String, arrayContains value: Any) -> QueryPredicate {
    return .arrayContains(field: name, value: value)
  }

  public static func whereField(_ name: String, arrayContainsAny values: [Any]) -> QueryPredicate {
    return .arrayContainsAny(field: name, values: values)
  }

  public static func whereField(_ name: String, isLessThan value: Any) -> QueryPredicate {
    return .isLessThan(field: name, value: value)
  }

  public static func whereField(_ name: String, isGreaterThan value: Any) -> QueryPredicate {
    return .isGreaterThan(field: name, value: value)
  }

  public static func whereField(_ name: String, isLessThanOrEqualTo value: Any) -> QueryPredicate {
    return .isLessThanOrEqualTo(field: name, value: value)
  }

  public static func whereField(_ name: String,
                                isGreaterThanOrEqualTo value: Any) -> QueryPredicate {
    return .isGreaterThanOrEqualTo(field: name, value: value)
  }

  // -- alternative naming 3

  public static func `where`(field name: String, isEqualTo value: Any) -> QueryPredicate {
    return .isEqualTo(field: name, value: value)
  }

  public static func `where`(field name: String, isIn values: [Any]) -> QueryPredicate {
    return .isIn(field: name, values: values)
  }

  public static func `where`(field name: String, isNotIn values: [Any]) -> QueryPredicate {
    return .isNotIn(field: name, values: values)
  }

  public static func `where`(field name: String, arrayContains value: Any) -> QueryPredicate {
    return .arrayContains(field: name, value: value)
  }

  public static func `where`(field name: String, arrayContainsAny values: [Any]) -> QueryPredicate {
    return .arrayContainsAny(field: name, values: values)
  }

  public static func `where`(field name: String, isLessThan value: Any) -> QueryPredicate {
    return .isLessThan(field: name, value: value)
  }

  public static func `where`(field name: String, isGreaterThan value: Any) -> QueryPredicate {
    return .isGreaterThan(field: name, value: value)
  }

  public static func `where`(field name: String, isLessThanOrEqualTo value: Any) -> QueryPredicate {
    return .isLessThanOrEqualTo(field: name, value: value)
  }

  public static func `where`(field name: String,
                             isGreaterThanOrEqualTo value: Any) -> QueryPredicate {
    return .isGreaterThanOrEqualTo(field: name, value: value)
  }
}

@available(iOS 13.0, *)
private class FirestoreQueryObservable<T: Decodable>: ObservableObject {
  @Published var items: [T] = []

  private let firestore = Firestore.firestore()
  private var listener: ListenerRegistration? = nil

  init(collectionPath: String, predicates: [QueryPredicate]) {
    setupListener(for: collectionPath, withPredicates: predicates)
  }

  deinit {
    removeListener()
  }

  private func removeListener() {
    listener?.remove()
  }

  private func setupListener(for collectionPath: String,
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
      }
    }

    listener = query.addSnapshotListener { snapshot, error in
      guard error == nil, let snapshot = snapshot else {
        self.items = []
        return
      }

      self.items = snapshot.documents.compactMap { document in
        try? document.data(as: T.self)
      }
    }
  }
}

@available(iOS 14.0, *)
@propertyWrapper
public struct FirestoreQuery<T: Decodable>: DynamicProperty {
  @StateObject private var queryObservable: FirestoreQueryObservable<T>

  public var wrappedValue: [T] {
    queryObservable.items
  }

  public init(collectionPath: String, predicates: [QueryPredicate] = []) {
    _queryObservable =
      StateObject(wrappedValue: FirestoreQueryObservable<T>(collectionPath: collectionPath,
                                                            predicates: predicates))
  }
}
