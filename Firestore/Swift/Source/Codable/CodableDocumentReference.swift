//
//  CodableDocumentReference.swift
//  FirebaseFirestoreSwift
//
//  Created by Oleksii on 22/02/2018.
//

import FirebaseFirestore

enum FirestoreDecodingError: Error {
    case decodingIsNotSupported
}

enum FirestoreEncodingError: Error {
    case encodingIsNotSupported
}

/**
 * A protocol describing the encodable properties of a DocumentReference.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the DocumentReference class was
 * extended directly to conform to Codable, the methods implementing the protcol would be need to be
 * marked required but that can't be done in an extension. Declaring the extension on the protocol
 * sidesteps this issue.
 */
fileprivate protocol CodableDocumentReference: Codable {}

extension CodableDocumentReference {
    public init(from decoder: Decoder) throws {
        throw FirestoreDecodingError.decodingIsNotSupported
    }
    
    public func encode(to encoder: Encoder) throws {
        throw FirestoreEncodingError.encodingIsNotSupported
    }
}

extension DocumentReference: CodableDocumentReference {}
