//
//  Transaction+Combine.swift
//  Forvice
//
//  Created by Lorenzo Fiamingo on 05/11/20.
//

#if canImport(Combine) && swift(>=5.0)

import Combine
import FirebaseFirestore

extension Firestore {
    
    func runTransactionPublisher<T>(_ updateBlock: @escaping (Transaction) throws -> T) -> Future<T, Error> {
        Future { self.runTransaction(updateBlock, completion: $0) }
    }
}

#endif
