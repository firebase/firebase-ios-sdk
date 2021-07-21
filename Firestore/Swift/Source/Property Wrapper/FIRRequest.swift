//
//  FIRRequest
//
//  Created by Florian Schweizer on 12.07.21.
//

import FirebaseFirestore
import SwiftUI

public enum FIRPredicate {
    case isEqualTo(_ lhs: String, _ rhs: Any)
    
    case isIn(_ lhs: String, rhs: [Any])
    case isNotIn(_ lhs: String, _ rhs: [Any])
    
    case arrayContains(_ lhs: String, _ rhs: Any)
    case arrayContainsAny(_ lhs: String, _ rhs: [Any])
    
    case isLessThan(_ lhs: String, _ rhs: Any)
    case isGreaterThan(_ lhs: String, _ rhs: Any)
    
    case isLessThanOrEqualTo(_ lhs: String, _ rhs: Any)
    case isGreaterThanOrEqualTo(_ lhs: String, _ rhs: Any)
}

@available(iOS 13.0, *)
public class FirebaseStore<T: Decodable>: ObservableObject {
    @Published var items: [T] = []
    
    private let store = Firestore.firestore()
    
    init(_ collection: String, _ predicates: [FIRPredicate]) {
        load(from: collection, withPredicates: predicates)
    }
    
    private func load(from collection: String, withPredicates predicates: [FIRPredicate]) {
        var query: Query = store.collection(collection)
        
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
        
        query
            .getDocuments { snapshot, error in
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
public struct FIRRequest<T: Decodable>: DynamicProperty {
    @StateObject public var store: FirebaseStore<T>
    
    public var wrappedValue: [T] {
        get {
            store.items
        }
        nonmutating set {
            store.items = newValue
        }
    }
    
    public init(_ collection: String, predicates: [FIRPredicate] = []) {
        self._store = StateObject(wrappedValue: FirebaseStore<T>(collection, predicates))
    }
}
