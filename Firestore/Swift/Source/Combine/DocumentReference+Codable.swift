//
//  DocumentReference+Codable.swift
//  abseil
//
//  Created by Lorenzo Fiamingo on 11/11/20.
//

#if canImport(Combine) && swift(>=5.0)

import Combine
import FirebaseFirestore


extension DocumentReference {
    
    func setDataPublisher(_ documentData: [String: Any]) -> Future<Void, Error> {
        Future { self.setData(documentData, completion: $0) }
    }
    
    func setDataPublisher(_ documentData: [String: Any], merge: Bool) -> Future<Void, Error> {
        Future { self.setData(documentData, merge: merge,  completion: $0) }
    }
    
    func setDataPublisher(_ documentData: [String: Any], mergeFields: [Any]) -> Future<Void, Error> {
        Future { self.setData(documentData, mergeFields: mergeFields,  completion: $0) }
    }
    
    func setDataPublisher<T: Encodable>(from value: T, encoder: Firestore.Encoder = Firestore.Encoder()) -> Future<Void, Error> {
        Future { promise in
            do {
                try self.setData(from: value, completion: promise)
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    func setDataPublisher<T: Encodable>(from value: T, merge: Bool, encoder: Firestore.Encoder = Firestore.Encoder()) -> Future<Void, Error> {
        Future { promise in
            do {
                try self.setData(from: value, merge: merge, completion: promise)
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    func setDataPublisher<T: Encodable>(from value: T, mergeFields: [Any], encoder: Firestore.Encoder = Firestore.Encoder()) -> Future<Void, Error> {
        Future { promise in
            do {
                try self.setData(from: value, mergeFields: mergeFields, completion: promise)
            } catch {
                promise(.failure(error))
            }
        }
    }
    
    func updateDataPublisher(_ documentData: [String: Any]) -> Future<Void, Error> {
        Future { self.updateData(documentData, completion: $0) }
    }
    
    func deletePublisher() -> Future<Void, Error> {
        Future(delete)
    }
    
    func getDocumentPublisher(source: FirestoreSource = .default) -> Future<DocumentSnapshot, Error> {
        Future { self.getDocument(source: source, completion: $0) }
    }
    
    func addSnapshotListenerPublisher(includeMetadataChanges: Bool = false) -> AnyPublisher<DocumentSnapshot, Error> {
        let subject = PassthroughSubject<DocumentSnapshot, Error>()
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
