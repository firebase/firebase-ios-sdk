//
//  ExplicitNull+Hashable.swift
//  
//
//  Created by Lorenzo Fiamingo on 08/08/20.
//

import FirebaseFirestore

extension ExplicitNull: Hashable where Value: Hashable {
    
    static func == (lhs: ExplicitNull, rhs: ExplicitNull) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}
