//
//  DocumentReference+Codable.swift
//  BoringSSL-GRPC-iOS
//
//  Created by 1amageek on 2019/03/26.
//

import Foundation
import FirebaseFirestore

/**
 * A protocol describing the encodable properties of a Timestamp.
 *
 * Note: this protocol exists as a workaround for the Swift compiler: if the Timestamp class
 * was extended directly to conform to Codable, the methods implementing the protocol would be need
 * to be marked required but that can't be done in an extension. Declaring the extension on the
 * protocol sidesteps this issue.
 */
private protocol CodableDocumentReference: Codable {

}


extension CodableDocumentReference {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        _ = try container.decode(DocumentReference.self)
        throw FirestoreDecodingError.decodingIsNotSupported
    }

    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
    }
}

extension DocumentReference: CodableDocumentReference { }
