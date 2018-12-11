//
//  Errors.swift
//  FirebaseFirestoreSwift
//
//  Created by Oleksii on 27/02/2018.
//

import Foundation

enum FirestoreDecodingError: Error {
    case decodingIsNotSupported
}

enum FirestoreEncodingError: Error {
    case encodingIsNotSupported
}
