//
//  FIeldPath+Expressible.swift
//  FirebaseFirestore
//
//  Created by Mark Duckworth on 8/2/24.
//

import Foundation

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE
// extension FieldPath : ExpressibleByStringLiteral {
// public required convenience init(stringLiteral: String) {
// self.init([stringLiteral])
// }
// }

private protocol ExpressibleByStringLiteralFieldPath: ExpressibleByStringLiteral {
  init(_: [String])
}

/**
 * An extension of VectorValue that implements the behavior of the Codable protocol.
 *
 * Note: this is implemented manually here because the Swift compiler can't synthesize these methods
 * when declaring an extension to conform to Codable.
 */
extension ExpressibleByStringLiteralFieldPath {
  public init(stringLiteral: String) {
    self.init([stringLiteral])
  }
}

/** Extends VectorValue to conform to Codable. */
extension FieldPath: ExpressibleByStringLiteralFieldPath {}
