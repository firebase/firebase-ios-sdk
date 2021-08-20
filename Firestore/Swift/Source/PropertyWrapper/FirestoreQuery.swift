/*
 * Copyright 2021 Google LLC
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
import SwiftUI

@available(iOS 14.0, *)
@propertyWrapper
public struct FirestoreQuery<T: Decodable>: DynamicProperty {
  @StateObject private var firestoreQueryObservable: FirestoreQueryObservable<T>

  public var wrappedValue: [T] {
    firestoreQueryObservable.items
  }

  public var projectedValue: FirestoreQueryConfiguration {
    get {
      firestoreQueryObservable.configuration
    }
    nonmutating set {
      firestoreQueryObservable.objectWillChange.send()
      firestoreQueryObservable.configuration = newValue
    }
  }

  public init(collectionPath: String, predicates: [QueryPredicate] = []) {
    let configuration = FirestoreQueryConfiguration(path: collectionPath, predicates: predicates)

    _firestoreQueryObservable =
      StateObject(wrappedValue: FirestoreQueryObservable<T>(configuration: configuration))
  }
}
