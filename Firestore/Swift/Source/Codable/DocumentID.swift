/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if SWIFT_PACKAGE
  @_exported import FirebaseFirestoreInternalWrapper
#else
  @_exported import FirebaseFirestoreInternal
#endif // SWIFT_PACKAGE

@_implementationOnly import FirebaseCoreExtension
import FirebaseSharedSwift

extension CodingUserInfoKey {
  static let documentRefUserInfoKey =
    CodingUserInfoKey(rawValue: "DocumentRefUserInfoKey")!
}

/// A type that can initialize itself from a Firestore `DocumentReference`,
/// which makes it suitable for use with the `@DocumentID` property wrapper.
///
/// Firestore includes extensions that make `String` and `DocumentReference`
/// conform to `DocumentIDWrappable`.
///
/// Note that Firestore ignores fields annotated with `@DocumentID` when writing
/// so there is no requirement to convert from the wrapped type back to a
/// `DocumentReference`.
public protocol DocumentIDWrappable {
  /// Creates a new instance by converting from the given `DocumentReference`.
  static func wrap(_ documentReference: DocumentReference) throws -> Self
}

extension String: DocumentIDWrappable {
  public static func wrap(_ documentReference: DocumentReference) throws -> Self {
    return documentReference.documentID
  }
}

extension DocumentReference: DocumentIDWrappable {
  public static func wrap(_ documentReference: DocumentReference) throws -> Self {
    // Swift complains that values of type DocumentReference cannot be returned
    // as Self which is nonsensical. The cast forces this to work.
    return documentReference as! Self
  }
}

/// An internal protocol that allows Firestore.Decoder to test if a type is a
/// DocumentID of some kind without knowing the specific generic parameter that
/// the user actually used.
///
/// This is required because Swift does not define an existential type for all
/// instances of a generic class--that is, it has no wildcard or raw type that
/// matches a generic without any specific parameter. Swift does define an
/// existential type for protocols though, so this protocol (to which DocumentID
/// conforms) indirectly makes it possible to test for and act on any
/// `DocumentID<Value>`.
protocol DocumentIDProtocol {
  /// Initializes the DocumentID from a DocumentReference.
  init(from documentReference: DocumentReference?) throws
}

/// A property wrapper type that marks a `DocumentReference?` or `String?` field to
/// be populated with a document identifier when it is read.
///
/// Apply the `@DocumentID` annotation to a `DocumentReference?` or `String?`
/// property in a `Codable` object to have it populated with the document
/// identifier when it is read and decoded from Firestore.
///
/// - Important: The name of the property annotated with `@DocumentID` must not
///   match the name of any fields in the Firestore document being read or else
///   an error will be thrown. For example, if the `Codable` object has a
///   property named `firstName` annotated with `@DocumentID`, and the Firestore
///   document contains a field named `firstName`, an error will be thrown when
///   attempting to decode the document.
///
/// - Example Read:
///   ````
///   struct Player: Codable {
///     @DocumentID var playerID: String?
///     var health: Int64
///   }
///
///   let p = try! await Firestore.firestore()
///       .collection("players")
///       .document("player-1")
///       .getDocument(as: Player.self)
///   print("\(p.playerID!) Health: \(p.health)")
///
///   // Prints: "Player: player-1, Health: 95"
///   ````
///
/// - Important: Trying to encode/decode this type using encoders/decoders other than
///   Firestore.Encoder throws an error.
///
/// - Important: When writing a Codable object containing an `@DocumentID` annotated field,
///   its value is ignored. This allows you to read a document from one path and
///   write it into another without adjusting the value here.
@propertyWrapper
public struct DocumentID<Value: DocumentIDWrappable & Codable>:
  StructureCodingUncodedUnkeyed {
  private var value: Value? = nil

  public init(wrappedValue value: Value?) {
    if let value = value {
      logIgnoredValueWarning(value: value)
    }
    self.value = value
  }

  public var wrappedValue: Value? {
    get { value }
    set {
      if let someNewValue = newValue {
        logIgnoredValueWarning(value: someNewValue)
      }
      value = newValue
    }
  }

  private func logIgnoredValueWarning(value: Value) {
    FirebaseLogger.log(
      level: .warning,
      service: "[FirebaseFirestoreSwift]",
      code: "I-FST000002",
      message: """
      Attempting to initialize or set a @DocumentID property with a non-nil \
      value: "\(value)". The document ID is managed by Firestore and any \
      initialized or set value will be ignored. The ID is automatically set \
      when reading from Firestore.
      """
    )
  }
}

extension DocumentID: DocumentIDProtocol {
  init(from documentReference: DocumentReference?) throws {
    if let documentReference = documentReference {
      value = try Value.wrap(documentReference)
    } else {
      value = nil
    }
  }
}

extension DocumentID: Codable {
  /// A `Codable` object  containing an `@DocumentID` annotated field should
  /// only be decoded with `Firestore.Decoder`; this initializer throws if an
  /// unsupported decoder is used.
  ///
  /// - Parameter decoder: A decoder.
  /// - Throws: ``FirestoreDecodingError``
  public init(from decoder: Decoder) throws {
    guard let reference = decoder
      .userInfo[CodingUserInfoKey.documentRefUserInfoKey] as? DocumentReference else {
      throw FirestoreDecodingError.decodingIsNotSupported(
        """
        Could not find DocumentReference for user info key: \(CodingUserInfoKey
          .documentRefUserInfoKey).
        DocumentID values can only be decoded with Firestore.Decoder
        """
      )
    }
    try self.init(from: reference)
  }

  /// A `Codable` object  containing an `@DocumentID` annotated field can only
  /// be encoded  with `Firestore.Encoder`; this initializer always throws.
  ///
  /// - Parameter encoder: An invalid encoder.
  /// - Throws: ``FirestoreEncodingError``
  public func encode(to encoder: Encoder) throws {
    throw FirestoreEncodingError.encodingIsNotSupported(
      "DocumentID values can only be encoded with Firestore.Encoder"
    )
  }
}

extension DocumentID: Equatable where Value: Equatable {}

extension DocumentID: Hashable where Value: Hashable {}
