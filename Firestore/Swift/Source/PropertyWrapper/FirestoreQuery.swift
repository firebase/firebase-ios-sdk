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
}

@available(iOS 13.0, *)
public class QueryStore<T: Decodable>: ObservableObject {
    @Published var items: [T] = []
    
    private let firestore = Firestore.firestore()
    private var listener: ListenerRegistration? = nil
    
    init(collectionPath: String, predicates: [FIRPredicate]) {
        setupListener(from: collectionPath, withPredicates: predicates)
    }
    
    deinit {
        removeListener()
    }
    
    private func setupListener(from collectionPath: String, withPredicates predicates: [FIRPredicate]) {
        var query: Query = firestore.collection(collectionPath)
        
        for predicate in predicates {
            switch predicate {
                case .isEqualTo(let lhs, let rhs):
                    query = query.whereField(lhs, isEqualTo: rhs)
                case .isIn(let lhs, let rhs):
                    query = query.whereField(lhs, in: rhs)
                case .isNotIn(let lhs, let rhs):
                    query = query.whereField(lhs, notIn: rhs)
                case .arrayContains(let lhs, let rhs):
                    query = query.whereField(lhs, arrayContains: rhs)
                case .arrayContainsAny(let lhs, let rhs):
                    query = query.whereField(lhs, arrayContainsAny: rhs)
                case .isLessThan(let lhs, let rhs):
                    query = query.whereField(lhs, isLessThan: rhs)
                case .isGreaterThan(let lhs, let rhs):
                    query = query.whereField(lhs, isGreaterThan: rhs)
                case .isLessThanOrEqualTo(let lhs, let rhs):
                    query = query.whereField(lhs, isLessThanOrEqualTo: rhs)
                case .isGreaterThanOrEqualTo(let lhs, let rhs):
                    query = query.whereField(lhs, isGreaterThanOrEqualTo: rhs)
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
    @StateObject public var store: QueryStore<T>
    
    private(set) public var wrappedValue: [T] {
        get {
            store.items
        }
        nonmutating set {
            store.items = newValue
        }
    }
    
    public init(_ collection: String, predicates: [FIRPredicate] = []) {
        self._store = StateObject(wrappedValue: QueryStore<T>(collectionPath: collection, predicates: predicates))
    }
}
