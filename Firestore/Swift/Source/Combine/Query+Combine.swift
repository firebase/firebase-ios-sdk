//
//  Query+Combine.swift
//  Forvice
//
//  Created by Lorenzo Fiamingo on 16/09/20.
//

#if canImport(Combine) && swift(>=5.0)

import Combine
import FirebaseFirestore

extension Query {
    
    func getDocumentsPublisher(source: FirestoreSource = .default) -> Future<QuerySnapshot, Error> {
        Future { self.getDocuments(source: source, completion: $0) }
    }
    
    func addSnapshotListenerPublisher(includeMetadataChanges: Bool = false) -> AnyPublisher<QuerySnapshot, Error> {
        let subject = PassthroughSubject<QuerySnapshot, Error>()
        let listenerHandle = addSnapshotListener { result in
            switch result {
                case .success(let output):
                    subject.send(output)
                case .failure(let error):
                    subject.send(completion: .failure(error))
            }
        }
        return subject
            .handleEvents(receiveCancel: listenerHandle.remove)
            .eraseToAnyPublisher()
    }
}

#endif
