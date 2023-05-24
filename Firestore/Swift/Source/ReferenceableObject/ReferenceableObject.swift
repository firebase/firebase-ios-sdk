/*
 * Copyright 2023 Google LLC
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

import FirebaseFirestore

import CryptoKit
import OSLog

/// A protocol that denotes an object that can be "stored by reference" in Firestore.
/// Structs that implement this and are contained in other Structs, are stored as a reference
/// instead of stored inline if the FirestoreObjRef propertyWrapper is used  to annotate them.
///
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol ReferenceableObject: Codable, Identifiable, Hashable, Equatable {
  // The Firestore collection where objects of this type are stored.
  // If no value is specified, it defaults to Type name of the object
  static func parentCollection() -> String

  var id: String? { get set }

  var path: String? { get }

  static func objectPath(objectId: String) -> String
}

// default implementations
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension ReferenceableObject {
  static func parentCollection() -> String {
    let t = type(of: self)
    return String(describing: t)
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(path)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    if let lpath = lhs.path,
       let rpath = rhs.path {
      return lpath == rpath
    } else {
      return false
    }
  }

  var path: String? {
    guard let id else {
      return nil
    }

    return Self.objectPath(objectId: id)
  }

  // Helper function that creates a path for the object
  static func objectPath(objectId: String) -> String {
    let coll = Self.parentCollection()
    if coll.hasSuffix("/") {
      return coll + objectId
    } else {
      return coll + "/" + objectId
    }
  }
}

// MARK: Contained Object Reference

/// Struct used to store a reference to a ReferenceableObject. When a container Struct is
/// encoded, any FirestoreObjRef property wrappers are encoded as ObjReference objects and the referenced
/// objects are stored (if needed) in their intended location instead of inline.
///
/// For example:
/// When storing UserProfile, which contains an Employer referenceable object,  Employer object is stored
/// in the Employer collection and a reference to Employer is stored within the UserProfile encoded document.
///
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct ObjReference<T: ReferenceableObject>: Codable {
  public var documentId: String
  public var collection: String
  public var placeholder: Codable?

  ///
  public var referencedObj: T?

  enum CodingKeys: String, CodingKey {
    case documentId = "docId"
    case collection
  }

  /// Loads the referenced object from the db and assigns it to the referencedObj property
  public mutating func loadObject() async throws {
    let obj: T? = try await ReferenceableObjectManager.instance.getObject(objId: documentId)
    referencedObj = obj
  }
}

// MARK: Logger

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension OSLog {
  static var storeByReference = OSLog(
    subsystem: "com.google.firebase.firestore",
    category: "storeByReference"
  )

  func debug(_ message: StaticString, _ args: CVarArg...) {
    os_log(message, log: self, type: .debug, args)
  }

  func info(_ message: StaticString, _ args: CVarArg...) {
    os_log(message, log: self, type: .info, args)
  }

  func log(_ message: StaticString, _ args: CVarArg...) {
    os_log(message, log: self, type: .default, args)
  }

  func error(_ message: StaticString, _ args: CVarArg) {
    os_log(message, log: self, type: .error, args)
  }

  func fault(_ message: StaticString, args: CVarArg) {
    os_log(message, log: self, type: .fault, args)
  }
}
