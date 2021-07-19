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

@propertyWrapper
public class FIRRequest<T: Decodable> {
    @Published public var wrappedValue: [T] = []
    
    private let store = Firestore.firestore()
    
    public init(_ collection: String, _ predicates: [FIRPredicate] = []) {
        load(from: collection, withPredicates: predicates)
    }
    
    private func load(from collection: String, withPredicates predicates: [FIRPredicate] = []) {
        let reference = store.collection(collection)
        
        if predicates.isEmpty {
            reference
                .getDocuments { snapshot, error in
                    guard error == nil, let snapshot = snapshot else {
                        return
                    }
                    
                    self.wrappedValue = snapshot.documents.compactMap { document in
                        try? document.data(as: T.self)
                    }
                }
        } else {
            var query: Query? = nil
            for predicate in predicates {
                switch predicate {
                    case .isEqualTo(let lhs, let rhs):
                        if let tempQuery = query {
                            query = tempQuery.whereField(lhs, isEqualTo: rhs)
                        } else {
                            query = reference.whereField(lhs, isEqualTo: rhs)
                        }
                    case .isIn(let lhs, let rhs):
                        if let tempQuery = query {
                            query = tempQuery.whereField(lhs, in: rhs)
                        } else {
                            query = reference.whereField(lhs, in: rhs)
                        }
                    case .isNotIn(let lhs, let rhs):
                        if let tempQuery = query {
                            query = tempQuery.whereField(lhs, notIn: rhs)
                        } else {
                            query = reference.whereField(lhs, notIn: rhs)
                        }
                    case .arrayContains(let lhs, let rhs):
                        if let tempQuery = query {
                            query = tempQuery.whereField(lhs, arrayContains: rhs)
                        } else {
                            query = reference.whereField(lhs, arrayContains: rhs)
                        }
                    case .arrayContainsAny(let lhs, let rhs):
                        if let tempQuery = query {
                            query = tempQuery.whereField(lhs, arrayContainsAny: rhs)
                        } else {
                            query = reference.whereField(lhs, arrayContainsAny: rhs)
                        }
                    case .isLessThan(let lhs, let rhs):
                        if let tempQuery = query {
                            query = tempQuery.whereField(lhs, isLessThan: rhs)
                        } else {
                            query = reference.whereField(lhs, isLessThan: rhs)
                        }
                    case .isGreaterThan(let lhs, let rhs):
                        if let tempQuery = query {
                            query = tempQuery.whereField(lhs, isGreaterThan: rhs)
                        } else {
                            query = reference.whereField(lhs, isGreaterThan: rhs)
                        }
                    case .isLessThanOrEqualTo(let lhs, let rhs):
                        if let tempQuery = query {
                            query = tempQuery.whereField(lhs, isLessThanOrEqualTo: rhs)
                        } else {
                            query = reference.whereField(lhs, isLessThanOrEqualTo: rhs)
                        }
                    case .isGreaterThanOrEqualTo(let lhs, let rhs):
                        if let tempQuery = query {
                            query = tempQuery.whereField(lhs, isGreaterThanOrEqualTo: rhs)
                        } else {
                            query = reference.whereField(lhs, isGreaterThanOrEqualTo: rhs)
                        }
                }
            }
            
            query?
                .getDocuments { snapshot, error in
                    guard error == nil, let snapshot = snapshot else {
                        return
                    }
                    
                    self.wrappedValue = snapshot.documents.compactMap { document in
                        try? document.data(as: T.self)
                    }
                }
        }
    }
}
