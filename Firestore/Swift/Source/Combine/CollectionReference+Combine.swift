//
//  CollectionReference+Combine.swift
//  Forvice
//
//  Created by Lorenzo Fiamingo on 16/09/20.
//

#if canImport(Combine) && swift(>=5.0)

import Combine
import FirebaseFirestore

extension CollectionReference {
    
    public func addDocumentPublisher(data: [String: Any]) -> AnyPublisher<DocumentReference, Error> {
        var reference: DocumentReference!
        return Future { reference = self.addDocument(data: data, completion: $0) }
            .map { reference }
            .eraseToAnyPublisher()
    }
    
    public func addDocumentPublisher<T: Encodable>(from value: T, encoder: Firestore.Encoder = Firestore.Encoder()) -> AnyPublisher<DocumentReference, Error> {
        var reference: DocumentReference!
        return Future { promise in
            do {
                try reference = self.addDocument(from: value, encoder: encoder, completion: promise)
            } catch {
                promise(.failure(error))
            }
        }
        .map { reference }
        .eraseToAnyPublisher()
    }
}

#endif
