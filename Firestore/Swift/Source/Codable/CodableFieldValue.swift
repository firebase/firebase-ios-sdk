//
//  CodableFieldValue.swift
//  FirebaseFirestoreSwift
//
//  Created by Oleksii on 22/02/2018.
//

import FirebaseFirestore

/**
 * A protocol describing the encodable properties of a FirebaseFirestore.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the FirebaseFirestore class was
 * extended directly to conform to Codable, the methods implementing the protcol would be need to be
 * marked required but that can't be done in an extension. Declaring the extension on the protocol
 * sidesteps this issue.
 */
fileprivate protocol CodableFieldValue: Encodable {}

extension CodableFieldValue {
    public func encode(to encoder: Encoder) throws {
        throw FirestoreEncodingError.encodingIsNotSupported
    }
}

extension FieldValue: CodableFieldValue {}
