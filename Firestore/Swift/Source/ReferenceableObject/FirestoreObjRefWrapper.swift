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

/// Property wrapper @FirestoreObjectReference,
/// Indicates that the specified property value should be stored by reference instead of by value,  inline
/// with the parent object.
///
/// When loading a parent object, any references are not loaded by default and can be loaded on demand
/// using the projected value of the wrapper.
///
/// structs that can be stored as a reference must implement the `ReferenceableObject` protocol
///
/// variables that are annotated with the propertyWrapper should be marked as `Optional` since they can be nil when not loaded or set
///
/// Example:
/// We have three structs representing a simplified UserProfile model -
/// `UserProfile`
/// `Employer` - an employer who the `UserProfile` works for
/// `WorkLocation` - representing a generic location. This can be used to represent a generic location
///
/// Since multiple Users can work for an Employer, it makes sense to have only one instance of an Employer that is referred to
/// by multiple Users. Similarly multiple users can be in a WorkLocation. Additionally, an Employer can also be located
/// in a WorkLocation (e.g. headquarters of an Employer). We can mark WorkLocation and Employer as a ReferenceableObjects.
///
///
/// ```
/// struct UserProfile: ReferenceableObject {
///     var username: String
///
///     @FirestoreObjRef
///     var employer: Employer?
///
///     @FirestoreObjRef
///     var workLocation: WorkLocation?
///
/// }
///
/// struct Employer: ReferenceableObject {
///     var name: String
///
///     @FirestoreObjRef
///     var headquarters: WorkLocation?
/// }
///
/// struct WorkLocation: ReferenceableObject {
///     var locationName: String
///     var moreInfo: String //
///
/// }
///
/// var userProfile = ...
///
/// // use projected value to load referenced employer
/// try await userProfile.$employer?.loadObject()
///
/// // use projected value to load referenced workLocation
/// try await prof.$workLocation?.loadObject()
///
///
///
/// ```
///
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@propertyWrapper
public struct FirestoreObjRef<T> where T: ReferenceableObject {
  private var objReference: ObjReference<T>?

  public init(wrappedValue initialValue: T?) {
    updateInitialValue(initialValue: initialValue)
  }

  private mutating func updateInitialValue(initialValue: T?) {
    if var initialValue {
      var oid = initialValue.id
      if oid == nil {
        let docRef = Firestore.firestore().collection(T.parentCollection()).document()
        oid = docRef.documentID
        initialValue.id = oid
      }
      objReference = ObjReference(
        documentId: oid!,
        collection: T.parentCollection(),
        referencedObj: initialValue
      )
    }
  }

  public var wrappedValue: T? {
    get {
      return objReference?.referencedObj
    }

    set {
      if objReference != nil {
        objReference?.referencedObj = newValue
      } else {
        updateInitialValue(initialValue: newValue)
      }
    }
  }

  public var projectedValue: ObjReference<T>? {
    get {
      return objReference
    }
    set {
      objReference = newValue
    }
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension FirestoreObjRef: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let objRef = try container.decode(ObjReference<T>.self)
    objReference = objRef
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if let objReference {
      try container.encode(objReference)

      if let value = objReference.referencedObj {
        Task {
          try await ReferenceableObjectManager.instance.save(object: value)
        }
      }

    } else {
      try container.encodeNil()
    }
  }
}
