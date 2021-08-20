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
